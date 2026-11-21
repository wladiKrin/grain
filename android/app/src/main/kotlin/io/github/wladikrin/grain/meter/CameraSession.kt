package io.github.wladikrin.grain.meter

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.Build
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Size
import android.view.Surface
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * One Camera2 session on the main back camera (or its separate ultra-wide when opened with
 * [startWide]): a preview into [surfaceTexture] and a YUV ImageReader whose Y plane feeds
 * [LumaStats] in [Mode.METER] or [QrDecoder] in [Mode.SCAN]. All camera work runs on a private
 * HandlerThread; [onReady], [onError], [onStats] and [onQr] are invoked on the main thread.
 * In [Mode.METER] the reader runs at preview size, so [requestSnapshot] can JPEG the next frame.
 */
class CameraSession(
    context: Context,
    private val surfaceTexture: SurfaceTexture,
    val mode: Mode,
    private val startWide: Boolean,
    private val onReady: (PreviewSetup) -> Unit,
    private val onError: (String) -> Unit,
    private val onStats: (Map<String, Any>) -> Unit,
    private val onQr: (String) -> Unit,
) {
    enum class Mode { METER, SCAN }

    data class PreviewSetup(
        val previewWidth: Int,
        val previewHeight: Int,
        val sensorOrientation: Int,
        /** The active camera's equivalent focal. */
        val phoneEqFocal: Double,
        val mainEqFocal: Double,
        /** Null when the phone has no ultra-wide. */
        val wideEqFocal: Double?,
        val wide: Boolean,
    )

    /** One [requestSnapshot] call; [finish] answers it once, on the main thread. */
    private inner class SnapshotRequest(val out: File, private val onDone: (String?) -> Unit) {
        private val answered = AtomicBoolean(false)

        fun finish(path: String?) {
            if (answered.compareAndSet(false, true)) mainHandler.post { onDone(path) }
        }
    }

    /** Regions in sensor-buffer coordinates, ready for [LumaStats.compute]. */
    private data class SensorRegions(val crop: RectD, val cx: Double, val cy: Double, val r: Double)

    private val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val thread = HandlerThread("GrainCamera").apply { start() }
    private val handler = Handler(thread.looper)
    private val executor = Executor { handler.post(it) }

    // Fixed after open() picked the camera; read on both threads.
    @Volatile private var sensorOrientation = 90
    @Volatile private var readerSize = Size(320, 240)
    @Volatile private var regions = SensorRegions(RectD(0.0, 0.0, 1.0, 1.0), 0.5, 0.5, 0.0)
    @Volatile private var displayRegions = DisplayRegions.DEFAULT

    // Camera-thread state.
    private var closed = false
    private var openInFlight = false
    private var finishClose: (() -> Unit)? = null
    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var reader: ImageReader? = null
    private var previewSurface: Surface? = null
    private var yBuffer = ByteArray(0)
    private var lastEmitMs = 0L
    private var minExposureNs = 0L
    private var maxExposureNs = 0L
    private var minIso = 0
    private var maxIso = 0
    private var defaultAperture = 0.0
    private var latest: TotalCaptureResult? = null
    private var wideSupport: Wide? = null
    private var request: CaptureRequest.Builder? = null
    private var current: PreviewSetup? = null
    private var lastQr: String? = null
    private val snapshots = mutableListOf<SnapshotRequest>()

    /** Display (portrait) regions as sent by Dart; normalized 0..1, radius relative to crop width. */
    data class DisplayRegions(val crop: RectD, val cx: Double, val cy: Double, val radius: Double) {
        companion object {
            val DEFAULT = DisplayRegions(RectD(0.0, 0.0, 1.0, 1.0), 0.5, 0.5, 0.02)
        }
    }

    fun open() = handler.post { openOnCameraThread() }

    /**
     * Switches to or from the ultra-wide. On the zoom-ratio path this updates the repeating
     * request in place and [onDone] gets the new setup; without an ultra-wide it gets the
     * unchanged setup. Null means this session cannot switch in place (the ultra-wide is a
     * separate camera, or the session is closed): the caller reopens with `startWide = want`.
     * [onDone] runs on the main thread.
     */
    fun setWide(want: Boolean, onDone: (PreviewSetup?) -> Unit) {
        val posted = handler.post {
            val result = setWideOnCameraThread(want)
            mainHandler.post { onDone(result) }
        }
        if (!posted) onDone(null) // The thread already quit after close().
    }

    private fun setWideOnCameraThread(want: Boolean): PreviewSetup? {
        val cur = current
        if (closed || cur == null) return null
        if (want == cur.wide) return cur
        return when (val w = wideSupport) {
            null -> cur
            is Wide.Camera -> null
            is Wide.ZoomRatio -> {
                val s = session ?: return null
                val b = request ?: return null
                try {
                    b.set(CaptureRequest.CONTROL_ZOOM_RATIO, if (want) w.ratio else 1f)
                    s.setRepeatingRequest(b.build(), captureCallback, handler)
                    cur.copy(wide = want, phoneEqFocal = if (want) w.eqFocal else cur.mainEqFocal)
                        .also { current = it }
                } catch (e: Exception) {
                    Log.w(TAG, "zoom ratio switch failed", e)
                    cur
                }
            }
        }
    }

    /**
     * METER mode: the next frame's lens crop, upright, as a JPEG at [out]; [onDone] gets the
     * path, or null (other mode, no frame within [SNAPSHOT_TIMEOUT_MS], session closed before a
     * frame arrived, encode failed). Once a frame is captured it is delivered even if the session
     * closes meanwhile. The camera thread only copies the planes; encoding runs on a background thread.
     * [onDone] runs on the main thread.
     */
    fun requestSnapshot(out: File, onDone: (String?) -> Unit) {
        val req = SnapshotRequest(out, onDone)
        if (mode != Mode.METER) {
            req.finish(null)
            return
        }
        val posted = handler.post {
            if (closed) {
                req.finish(null)
                return@post
            }
            snapshots.add(req)
            handler.postDelayed({
                if (snapshots.remove(req)) {
                    Log.w(TAG, "snapshot: no frame within $SNAPSHOT_TIMEOUT_MS ms")
                    req.finish(null)
                }
            }, SNAPSHOT_TIMEOUT_MS)
        }
        if (!posted) req.finish(null) // The thread already quit after close().
    }

    /** Camera thread: copies [img]'s planes and queues an encode for every waiting request. */
    private fun captureSnapshot(img: android.media.Image) {
        val waiting = snapshots.toList()
        snapshots.clear()
        val w = img.width
        val h = img.height
        val (yp, up, vp) = img.planes
        val y = copyOf(yp.buffer)
        val u = copyOf(up.buffer)
        val v = copyOf(vp.buffer)
        val yRowStride = yp.rowStride
        val uvRowStride = up.rowStride
        val uvPixelStride = up.pixelStride
        val crop = SnapshotEncoder.cropPixels(regions.crop, w, h)
        val orientation = sensorOrientation
        // The planes are private copies now, so the encode no longer depends on the session:
        // a close (Home, camera switch) during it still delivers the snapshot of the logged frame.
        encoder.execute {
            val jpeg = try {
                val nv21 = SnapshotEncoder.yuvToNv21(w, h, y, yRowStride, u, v, uvRowStride, uvPixelStride)
                SnapshotEncoder.encodeJpeg(nv21, w, h, crop, orientation)
            } catch (e: Exception) {
                Log.w(TAG, "snapshot encode failed", e)
                null
            }
            // Requests waiting on the same frame share the one encode, each in its own file.
            for (req in waiting) {
                if (jpeg == null) {
                    req.finish(null)
                    continue
                }
                try {
                    SnapshotEncoder.writeAtomically(jpeg, req.out)
                    req.finish(req.out.path)
                } catch (e: Exception) {
                    Log.w(TAG, "snapshot write failed", e)
                    req.out.delete()
                    req.finish(null)
                }
            }
        }
    }

    fun setRegions(r: DisplayRegions) {
        displayRegions = r
        regions = toSensor(r, sensorOrientation, readerSize)
    }

    /** Releases device, session and reader, then calls [onClosed] on the main thread. */
    fun close(onClosed: () -> Unit) {
        handler.post {
            closed = true
            snapshots.forEach { it.finish(null) }
            snapshots.clear()
            try {
                session?.close()
            } catch (_: Exception) {
            }
            device?.close()
            reader?.close()
            previewSurface?.release()
            session = null
            device = null
            reader = null
            previewSurface = null
            latest = null
            request = null
            current = null
            val finish: () -> Unit = {
                thread.quitSafely()
                mainHandler.post(onClosed)
            }
            // A pending openCamera still needs this thread to deliver (and close) the device.
            if (openInFlight) finishClose = finish else finish()
        }
    }

    /** Camera thread: an openCamera callback arrived; closes the device if close() came first. */
    private fun openSettled(camera: CameraDevice): Boolean {
        openInFlight = false
        if (!closed) return false
        camera.close()
        finishClose?.invoke()
        finishClose = null
        return true
    }

    @SuppressLint("MissingPermission") // The plugin checks CAMERA before creating a session.
    private fun openOnCameraThread() {
        try {
            val backs = backCameras(manager)
            val mainId = selectMainBackCamera(backs) ?: return fail("No back camera")
            val mainCh = backs.first { it.first == mainId }.second
            val mainEq = phoneEqFocal(eqFocal(mainCh))
            val zoomLower = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                mainCh.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)?.lower
            } else {
                null
            }
            val others = backs.filter { it.first != mainId }
                .mapNotNull { (id, ch) -> eqFocal(ch)?.takeIf { it.isFinite() && it > 0 }?.let { id to it } }
            val wideWay = WideSupport.choose(mainEq, zoomLower, Build.VERSION.SDK_INT, others)
            wideSupport = wideWay
            Log.i(TAG, "main camera $mainId eq ${"%.1f".format(mainEq)} mm; ultra-wide: ${describe(wideWay)}")

            val wide = startWide && wideWay != null
            val id = if (wide && wideWay is Wide.Camera) wideWay.id else mainId
            val ch = if (id == mainId) mainCh else backs.first { it.first == id }.second
            val activeEq = if (wide) eqOf(wideWay!!) else mainEq
            val zoomRatio = if (wide && wideWay is Wide.ZoomRatio) wideWay.ratio else null

            val map = ch.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?: return fail("No stream configuration")
            val preview = choosePreviewSize(map.getOutputSizes(SurfaceTexture::class.java))
                ?: return fail("No preview size")
            val yuvSizes = map.getOutputSizes(ImageFormat.YUV_420_888)
            // METER: preview-size frames for snapshots; LumaStats samples them sparsely.
            val yuv = (if (mode == Mode.SCAN) chooseScanSize(yuvSizes) else choosePreviewSize(yuvSizes))
                ?: return fail("No YUV size")

            sensorOrientation = ch.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
            readerSize = yuv
            setRegions(displayRegions)
            ch.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)?.let {
                minExposureNs = it.lower
                maxExposureNs = it.upper
            }
            ch.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)?.let {
                minIso = it.lower
                maxIso = it.upper
            }
            defaultAperture = ch.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)
                ?.firstOrNull()?.toDouble() ?: 0.0
            val setup = PreviewSetup(
                preview.width, preview.height, sensorOrientation,
                phoneEqFocal = activeEq,
                mainEqFocal = mainEq,
                wideEqFocal = wideWay?.let(::eqOf),
                wide = wide,
            )

            surfaceTexture.setDefaultBufferSize(preview.width, preview.height)
            val surface = Surface(surfaceTexture).also { previewSurface = it }
            val r = ImageReader.newInstance(yuv.width, yuv.height, ImageFormat.YUV_420_888, 3)
            reader = r
            r.setOnImageAvailableListener({ onImage(it) }, handler)

            openInFlight = true
            manager.openCamera(id, executor, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    if (openSettled(camera)) return
                    device = camera
                    configure(camera, surface, r.surface, ch, setup, zoomRatio)
                }

                override fun onDisconnected(camera: CameraDevice) {
                    if (openSettled(camera)) return
                    camera.close()
                    if (device === camera) device = null
                    fail("Camera disconnected")
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    if (openSettled(camera)) return
                    camera.close()
                    if (device === camera) device = null
                    fail("Camera device error $error")
                }
            })
        } catch (e: Exception) {
            openInFlight = false
            fail(e.message ?: e.javaClass.simpleName)
        }
    }

    private fun configure(
        camera: CameraDevice,
        preview: Surface,
        analysis: Surface,
        ch: CameraCharacteristics,
        setup: PreviewSetup,
        zoomRatio: Float?,
    ) {
        val outputs = listOf(OutputConfiguration(preview), OutputConfiguration(analysis))
        val config = SessionConfiguration(
            SessionConfiguration.SESSION_REGULAR, outputs, executor,
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(s: CameraCaptureSession) {
                    if (closed) {
                        s.close()
                        return
                    }
                    session = s
                    try {
                        val builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                            addTarget(preview)
                            addTarget(analysis)
                            set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                            set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
                            val afModes = ch.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)
                            if (afModes?.contains(CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE) == true) {
                                set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                            }
                            if (zoomRatio != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                set(CaptureRequest.CONTROL_ZOOM_RATIO, zoomRatio)
                            }
                        }
                        s.setRepeatingRequest(builder.build(), captureCallback, handler)
                        request = builder
                        current = setup
                        mainHandler.post { onReady(setup) }
                    } catch (e: Exception) {
                        fail(e.message ?: e.javaClass.simpleName)
                    }
                }

                override fun onConfigureFailed(s: CameraCaptureSession) {
                    fail("Capture session configuration failed")
                }
            },
        )
        try {
            camera.createCaptureSession(config)
        } catch (e: Exception) {
            fail(e.message ?: e.javaClass.simpleName)
        }
    }

    private val captureCallback = object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(s: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
            latest = result
        }
    }

    /**
     * Camera thread. Every Image is closed; stats are computed at most 15 times a second
     * (METER), a QR decode is tried at most every 200 ms (SCAN). A waiting snapshot takes the
     * first METER frame regardless of the stats rate.
     */
    private fun onImage(r: ImageReader) {
        val image = try {
            r.acquireLatestImage()
        } catch (_: IllegalStateException) {
            null
        } ?: return
        image.use { img ->
            if (closed) return
            val now = SystemClock.elapsedRealtime()
            if (mode == Mode.SCAN) {
                if (now - lastEmitMs < MIN_SCAN_INTERVAL_MS) return
                lastEmitMs = now
                val plane = img.planes[0]
                val buf = plane.buffer
                val n = buf.remaining()
                if (yBuffer.size < n) yBuffer = ByteArray(n)
                buf.get(yBuffer, 0, n)
                val text = QrDecoder.decode(yBuffer, img.width, img.height, plane.rowStride) ?: return
                if (text == lastQr) return
                lastQr = text
                mainHandler.post { onQr(text) }
                return
            }
            if (snapshots.isNotEmpty()) captureSnapshot(img)
            if (now - lastEmitMs < MIN_EVENT_INTERVAL_MS) return
            val result = latest ?: return
            val exposure = result.get(CaptureResult.SENSOR_EXPOSURE_TIME) ?: return
            val sensitivity = result.get(CaptureResult.SENSOR_SENSITIVITY) ?: return
            lastEmitMs = now

            // Reads only the sampled pixels from the plane; no per-frame copy of the preview-size Y.
            val plane = img.planes[0]
            val reg = regions
            val stats = LumaStats.compute(
                plane.buffer, img.width, img.height, plane.rowStride, reg.crop, reg.cx, reg.cy, reg.r,
                step = LumaStats.samplingStep(img.width),
            )
            val event = mapOf<String, Any>(
                "exposureNs" to exposure,
                "sensitivity" to sensitivity,
                "boost" to (result.get(CaptureResult.CONTROL_POST_RAW_SENSITIVITY_BOOST) ?: 100),
                "aperture" to (result.get(CaptureResult.LENS_APERTURE)?.toDouble() ?: defaultAperture),
                "minExposureNs" to minExposureNs,
                "maxExposureNs" to maxExposureNs,
                "minIso" to minIso,
                "maxIso" to maxIso,
                "frameLuma" to stats.frame,
                "cropLuma" to stats.crop,
                "spotLuma" to stats.spot,
                "histogram" to stats.histogram.toList(),
            )
            mainHandler.post { onStats(event) }
        }
    }

    private fun fail(message: String) {
        if (closed) return
        mainHandler.post { onError(message) }
    }

    companion object {
        private const val TAG = "GrainCamera"
        // 15 events/s at 30 and 60 fps (every 2nd / 4th frame); 1000/15+1 gave 10/s at 30 fps.
        private const val MIN_EVENT_INTERVAL_MS = 60L
        private const val MIN_SCAN_INTERVAL_MS = 200L
        private const val MIN_SCAN_EDGE = 1280
        private const val MAX_SCAN_EDGE = 1920
        private const val FULL_FRAME_DIAGONAL_MM = 43.27
        private const val TARGET_EQ_FOCAL_MM = 26.0
        private const val MAX_PREVIEW_EDGE = 1440
        private const val SNAPSHOT_TIMEOUT_MS = 1500L

        /** Shared low-priority thread for snapshot encodes, so they never compete with the camera. */
        private val encoder = Executors.newSingleThreadExecutor { r ->
            Thread(r, "GrainSnapshot").apply {
                isDaemon = true
                priority = Thread.MIN_PRIORITY
            }
        }

        /** The [buf]'s remaining bytes, without moving its position. */
        private fun copyOf(buf: java.nio.ByteBuffer): ByteArray =
            ByteArray(buf.remaining()).also { buf.duplicate().get(it) }

        /** Typical phone main camera, used when the characteristics give no focal length. */
        private const val FALLBACK_EQ_FOCAL_MM = 26.0

        /** [eq] when it is a usable focal length, else [FALLBACK_EQ_FOCAL_MM]. */
        fun phoneEqFocal(eq: Double?): Double =
            eq?.takeIf { it.isFinite() && it > 0 } ?: FALLBACK_EQ_FOCAL_MM

        /** 35 mm-equivalent focal length of a camera's first (main) focal length, mm. */
        fun eqFocal(ch: CameraCharacteristics): Double? {
            val f = ch.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.firstOrNull() ?: return null
            val size = ch.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: return null
            val diag = hypot(size.width.toDouble(), size.height.toDouble())
            if (diag <= 0.0) return null
            return f * FULL_FRAME_DIAGONAL_MM / diag
        }

        private fun eqOf(w: Wide) = when (w) {
            is Wide.ZoomRatio -> w.eqFocal
            is Wide.Camera -> w.eqFocal
        }

        private fun describe(w: Wide?) = when (w) {
            null -> "none"
            is Wide.ZoomRatio -> "zoom ratio ${w.ratio} (eq ${"%.1f".format(w.eqFocal)} mm)"
            is Wide.Camera -> "separate camera ${w.id} (eq ${"%.1f".format(w.eqFocal)} mm)"
        }

        /** Every back-facing camera with its characteristics. */
        fun backCameras(manager: CameraManager): List<Pair<String, CameraCharacteristics>> =
            manager.cameraIdList
                .map { it to manager.getCameraCharacteristics(it) }
                .filter { (_, ch) -> ch.get(CameraCharacteristics.LENS_FACING) == CameraMetadata.LENS_FACING_BACK }

        /** Of [backs], the camera whose equivalent focal length is closest to 26 mm. */
        fun selectMainBackCamera(backs: List<Pair<String, CameraCharacteristics>>): String? =
            backs.minByOrNull { (_, ch) -> eqFocal(ch)?.let { abs(it - TARGET_EQ_FOCAL_MM) } ?: Double.MAX_VALUE }
                ?.first

        private fun is4by3(s: Size) = max(s.width, s.height) * 3 == min(s.width, s.height) * 4

        /** Largest 4:3 size with long edge ≤ 1440 px; else the largest size within that edge. */
        fun choosePreviewSize(sizes: Array<Size>?): Size? {
            if (sizes.isNullOrEmpty()) return null
            val fitting = sizes.filter { max(it.width, it.height) <= MAX_PREVIEW_EDGE }
            return fitting.filter(::is4by3).maxByOrNull { it.width * it.height }
                ?: fitting.maxByOrNull { it.width * it.height }
                ?: sizes.minByOrNull { it.width * it.height }
        }

        /** Smallest 4:3 size with long edge ≥ 1280 px; else the largest with long edge ≤ 1920 px. */
        fun chooseScanSize(sizes: Array<Size>?): Size? {
            if (sizes.isNullOrEmpty()) return null
            return sizes.filter { is4by3(it) && max(it.width, it.height) >= MIN_SCAN_EDGE }
                .minByOrNull { it.width * it.height }
                ?: sizes.filter { max(it.width, it.height) <= MAX_SCAN_EDGE }.maxByOrNull { it.width * it.height }
                ?: sizes.minByOrNull { it.width * it.height }
        }

        private fun toSensor(r: DisplayRegions, orientation: Int, buffer: Size): SensorRegions {
            val (u1, v1) = LumaStats.displayToSensor(r.crop.l, r.crop.t, orientation)
            val (u2, v2) = LumaStats.displayToSensor(r.crop.r, r.crop.b, orientation)
            val crop = RectD(min(u1, u2), min(v1, v2), max(u1, u2), max(v1, v2))
            val (cx, cy) = LumaStats.displayToSensor(r.cx, r.cy, orientation)
            // The display's width runs along the buffer's height when the sensor is rotated 90/270.
            val quarterTurn = orientation % 180 != 0
            val displayWidthPx = if (quarterTurn) buffer.height else buffer.width
            val radiusPx = r.radius * (r.crop.r - r.crop.l) * displayWidthPx
            return SensorRegions(crop, cx, cy, radiusPx / buffer.width)
        }
    }
}
