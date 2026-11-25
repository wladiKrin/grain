package io.github.wladikrin.grain.meter

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
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
import android.hardware.camera2.params.TonemapCurve
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
import java.util.TimeZone
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * One Camera2 session on the main back camera (or its separate ultra-wide when opened with
 * [startZoom] below 1): a preview into [surfaceTexture] and a YUV ImageReader whose Y plane feeds
 * [LumaStats] in [Mode.METER] or [QrDecoder] in [Mode.SCAN]. All camera work runs on a private
 * HandlerThread; [onReady], [onError], [onStats] and [onQr] are invoked on the main thread.
 * In [Mode.METER] the reader runs at preview size, so [requestSnapshot] can JPEG the next frame.
 *
 * METER mode meters with the manual engine where the camera allows it (and [preferManual]):
 * AE off, exposure time and ISO set by [ExposureLoop], a known tone curve. Elsewhere, and in
 * [Mode.SCAN], the phone's AE runs and the reading follows its result.
 */
class CameraSession(
    context: Context,
    private val surfaceTexture: SurfaceTexture,
    val mode: Mode,
    /** Below 1 the ultra-wide, 1 the main camera, above 1 the main camera zoomed in. */
    private val startZoom: Float,
    /** Whether to meter with the manual engine where the camera supports it. */
    private var preferManual: Boolean,
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
        /** phoneEqFocal / mainEqFocal: the CONTROL_ZOOM_RATIO in use on the main camera. */
        val zoom: Float = 1f,
        /** Largest tele ratio of the main camera; 1 without camera zoom. */
        val maxZoom: Float = 1f,
    )

    /** One [requestSnapshot] call; [finish] answers it once, on the main thread. */
    private inner class SnapshotRequest(val out: File, private val onDone: (String?) -> Unit) {
        private val answered = AtomicBoolean(false)

        fun finish(path: String?) {
            if (answered.compareAndSet(false, true)) mainHandler.post { onDone(path) }
        }
    }

    /** Regions in sensor-buffer coordinates, ready for [LumaStats.compute]. */
    private data class SensorRegions(
        val crop: RectD,
        val cx: Double,
        val cy: Double,
        val r: Double,
        val spotMetering: Boolean = false,
    )

    private val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
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
    private var listedApertures: FloatArray? = null
    private var mainEq = FALLBACK_EQ_FOCAL_MM

    /** A physical camera of a logical multi-camera, as far as the phone describes it. */
    private class Physical(
        /** "main", "wide", "tele", or null when unknown. */
        val kind: String?,
        val apertures: FloatArray?,
        /** Its SENSOR_INFO exposure-time and sensitivity ranges; null when not listed. */
        val exposure: android.util.Range<Long>?,
        val iso: android.util.Range<Int>?,
    )

    /** Each physical camera seen. */
    private val physicals = mutableMapOf<String, Physical>()
    private var latest: TotalCaptureResult? = null
    private var wideSupport: Wide? = null
    private var request: CaptureRequest.Builder? = null
    private var current: PreviewSetup? = null
    private var lastQr: String? = null
    private val snapshots = mutableListOf<SnapshotRequest>()

    /** What the opened camera allows for the manual engine; null when it cannot run it. */
    private class Manual(
        val limits: ExposureLoop.Limits,
        val boostMin: Int?,
        val tone: ToneCurve.Choice,
        val curvePoints: Int,
        val maxFrameNs: Long?,
    )

    private var manual: Manual? = null

    /** Why [manual] is null, for the log. */
    private var manualWhy = ""

    /** Non-null while the repeating request runs AE off. */
    private var loop: ExposureLoop? = null

    /** The inverse [LumaStats] uses; the tone curve of the request in use. */
    private var curve = ToneCurve.SRGB

    /** The template's own tonemap mode, restored when AE takes over again. */
    private var templateTonemap: Int? = null

    /** Recent results by SENSOR_TIMESTAMP, so a frame's stats pair with its own result. */
    private val results = object : LinkedHashMap<Long, TotalCaptureResult>() {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Long, TotalCaptureResult>?) =
            size > RESULTS_KEPT
    }

    /** The manual engine's last region was white: the first one that is not goes to Dart at once. */
    private var lastWhite = false

    /**
     * A frame's stats waiting for its capture result; [spot] says which region was metered for
     * them, [emit] whether Dart gets them.
     */
    private class PendingFrame(val ts: Long, val stats: Stats, val spot: Boolean, val emit: Boolean)

    private var pendingFrame: PendingFrame? = null

    /** Display (portrait) regions as sent by Dart; normalized 0..1, radius relative to crop width. */
    data class DisplayRegions(
        val crop: RectD,
        val cx: Double,
        val cy: Double,
        val radius: Double,
        /** The spot, not the crop, is metered: the manual engine exposes for it. */
        val spotMetering: Boolean = false,
    ) {
        companion object {
            val DEFAULT = DisplayRegions(RectD(0.0, 0.0, 1.0, 1.0), 0.5, 0.5, 0.02)
        }
    }

    fun open() = handler.post { openOnCameraThread() }

    /**
     * Sets the camera's zoom: below 1 the ultra-wide, 1 the main camera, above 1 the main
     * camera zoomed in via CONTROL_ZOOM_RATIO (capped at [PreviewSetup.maxZoom]; on a logical
     * multi-camera the HAL moves to its telephoto by itself). On the main logical camera this
     * updates the repeating request in place and [onDone] gets the new setup; where nothing can
     * change (no ultra-wide, no zoom headroom) it gets the unchanged setup. Null means this
     * session cannot switch in place (to or from a separate ultra-wide camera, or the session
     * is closed): the caller reopens with `startZoom = want`. [onDone] runs on the main thread.
     */
    fun setZoom(want: Float, onDone: (PreviewSetup?) -> Unit) {
        val posted = handler.post {
            setZoomOnCameraThread(want) { result -> mainHandler.post { onDone(result) } }
        }
        if (!posted) onDone(null) // The thread already quit after close().
    }

    /**
     * Camera thread. On the zoom-ratio path [answer] waits for the first frame at the new
     * ratio, so the caller reframes when the picture changes, not a few frames before.
     */
    private fun setZoomOnCameraThread(want: Float, answer: (PreviewSetup?) -> Unit) {
        val cur = current
        if (closed || cur == null) return answer(null)
        val w = wideSupport
        val wantWide = want < 1f
        if (wantWide && (w == null || cur.wide)) return answer(cur)
        // To or from a separate ultra-wide: another camera, so the caller reopens.
        if (w is Wide.Camera && (wantWide || cur.wide)) return answer(null)
        val ratio = if (wantWide) (w as Wide.ZoomRatio).ratio else ZoomSupport.clampTele(want.toDouble(), cur.maxZoom)
        if (!cur.wide && !wantWide && zoomClose(cur.zoom, ratio)) return answer(cur)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return answer(cur)
        val s = session ?: return answer(null)
        val b = request ?: return answer(null)
        try {
            b.set(CaptureRequest.CONTROL_ZOOM_RATIO, ratio)
            s.setRepeatingRequest(b.build(), captureCallback, handler)
            val eq = if (wantWide) (w as Wide.ZoomRatio).eqFocal else cur.mainEqFocal * ratio
            val next = cur.copy(wide = wantWide, zoom = ratio, phoneEqFocal = eq)
            current = next
            Log.i(TAG, ZoomSupport.describeZoom(ratio, eq))
            afterFrame(ratio, onClose = true) { answer(next) }
        } catch (e: Exception) {
            Log.w(TAG, "zoom ratio switch failed", e)
            answer(cur)
        }
    }

    /** A wait for the first frame at [zoom] (any frame when null); see [afterFrame]. */
    private class FrameWait(val zoom: Float?, val onClose: Boolean, val action: () -> Unit) {
        var done = false
    }

    private var frameWait: FrameWait? = null

    /**
     * Camera thread. Runs [action] once a capture result arrives at [zoom], or after
     * [FRAME_WAIT_MS] at the latest. A newer wait settles the older one first; [onClose] says
     * whether [close] still runs it (an answer the caller waits for) or drops it.
     */
    private fun afterFrame(zoom: Float?, onClose: Boolean, action: () -> Unit) {
        frameWait?.let(::settle)
        val w = FrameWait(zoom, onClose, action)
        frameWait = w
        handler.postDelayed({ settle(w) }, FRAME_WAIT_MS)
    }

    private fun settle(w: FrameWait, run: Boolean = true) {
        if (w.done) return
        w.done = true
        if (frameWait === w) frameWait = null
        if (run) w.action()
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
            frameWait?.let { settle(it, run = it.onClose) }
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
            results.clear()
            pendingFrame = null
            loop = null
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
            this.mainEq = mainEq
            val zoomRange = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                mainCh.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
            } else {
                null
            }
            val zoomLower = zoomRange?.lower
            val maxZoom = ZoomSupport.maxRatio(Build.VERSION.SDK_INT, zoomRange?.upper)
            val others = backs.filter { it.first != mainId }
                .mapNotNull { (id, ch) -> eqFocal(ch)?.takeIf { it.isFinite() && it > 0 }?.let { id to it } }
            val wideWay = WideSupport.choose(mainEq, zoomLower, Build.VERSION.SDK_INT, others)
            wideSupport = wideWay
            Log.i(
                TAG,
                "main camera $mainId eq ${"%.1f".format(mainEq)} mm, zoom up to $maxZoom; " +
                    "ultra-wide: ${describe(wideWay)}",
            )

            val wide = startZoom < 1f && wideWay != null
            val id = if (wide && wideWay is Wide.Camera) wideWay.id else mainId
            val ch = if (id == mainId) mainCh else backs.first { it.first == id }.second
            val zoomRatio = when {
                wide && wideWay is Wide.ZoomRatio -> wideWay.ratio
                !wide && startZoom > 1f && maxZoom > 1f -> ZoomSupport.clampTele(startZoom.toDouble(), maxZoom)
                else -> null
            }
            val activeEq = if (wide) eqOf(wideWay!!) else mainEq * (zoomRatio ?: 1f)

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
            listedApertures = ch.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)
            manual = if (mode == Mode.METER) manualSupport(ch) else null
            val setup = PreviewSetup(
                preview.width, preview.height, sensorOrientation,
                phoneEqFocal = activeEq,
                mainEqFocal = mainEq,
                wideEqFocal = wideWay?.let(::eqOf),
                wide = wide,
                zoom = (activeEq / mainEq).toFloat(),
                maxZoom = maxZoom,
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
                            templateTonemap = get(CaptureRequest.TONEMAP_MODE)
                            val afModes = ch.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)
                            if (afModes?.contains(CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE) == true) {
                                set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                            }
                            if (zoomRatio != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                set(CaptureRequest.CONTROL_ZOOM_RATIO, zoomRatio)
                            }
                            // Zoom changes apply on the next frame instead of a few frames later.
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
                                ch.get(CameraCharacteristics.CONTROL_AVAILABLE_SETTINGS_OVERRIDES)
                                    ?.contains(CameraMetadata.CONTROL_SETTINGS_OVERRIDE_ZOOM) == true
                            ) {
                                set(
                                    CaptureRequest.CONTROL_SETTINGS_OVERRIDE,
                                    CameraMetadata.CONTROL_SETTINGS_OVERRIDE_ZOOM,
                                )
                            }
                        }
                        if (mode == Mode.METER) applyEngine(builder, log = true)
                        s.setRepeatingRequest(builder.build(), captureCallback, handler)
                        request = builder
                        current = setup
                        // Ready with the first frame, so a reopened camera's frame replaces the
                        // old camera's last one as the caller reframes.
                        afterFrame(zoomRatio, onClose = false) { mainHandler.post { onReady(setup) } }
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
            result.get(CaptureResult.SENSOR_TIMESTAMP)?.let { ts ->
                results[ts] = result
                val p = pendingFrame
                if (p != null && p.ts == ts) {
                    pendingFrame = null
                    if (!closed) emitStats(p.stats, p.spot, result, p.emit)
                }
            }
            val w = frameWait ?: return
            if (w.zoom == null || zoomReached(result, w.zoom)) settle(w)
        }
    }

    /**
     * Camera thread. Every Image is closed; stats are sent to Dart at most 15 times a second
     * (METER), but with the manual engine every frame steps the loop; a QR decode is tried at
     * most every 200 ms (SCAN). A waiting snapshot takes the first METER frame regardless of
     * the stats rate.
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
            val emit = now - lastEmitMs >= MIN_EVENT_INTERVAL_MS
            if (!emit && loop == null) return
            if (emit) lastEmitMs = now

            // Reads only the sampled pixels from the plane; no per-frame copy of the preview-size Y.
            val plane = img.planes[0]
            val reg = regions
            val stats = LumaStats.compute(
                plane.buffer, img.width, img.height, plane.rowStride, reg.crop, reg.cx, reg.cy, reg.r,
                step = LumaStats.samplingStep(img.width), curve = curve,
            )
            // The frame's own result: it says which exposure the frame really had. Results come
            // in order, so one newer than the frame means its own was lost (or this phone stamps
            // frames differently): the latest stands in, as before frames were paired.
            val ts = img.timestamp
            val own = results[ts]
            val newest = latest
            // The spot flag travels with the stats computed for it: setRegions may change both
            // before the frame's result arrives.
            val spot = reg.spotMetering
            when {
                own != null -> emitStats(stats, spot, own, emit)
                newest != null && (newest.get(CaptureResult.SENSOR_TIMESTAMP) ?: Long.MAX_VALUE) > ts ->
                    emitStats(stats, spot, newest, emit)
                // A newer frame replaces one still waiting, and keeps its event.
                else -> pendingFrame = PendingFrame(ts, stats, spot, emit || pendingFrame?.emit == true)
            }
        }
    }

    /**
     * Camera thread: steps the loop with [stats] (metered for the [spot] or the crop) and its
     * frame's [result]; when [emit], or when the region is no longer white (the first frame
     * that reads after a step down), also sends them to Dart as one stats event.
     */
    private fun emitStats(stats: Stats, spot: Boolean, result: CaptureResult, emit: Boolean) {
        val exposure = result.get(CaptureResult.SENSOR_EXPOSURE_TIME) ?: return
        val sensitivity = result.get(CaptureResult.SENSOR_SENSITIVITY) ?: return
        val manualFrame = result.get(CaptureResult.CONTROL_AE_MODE)?.let { it == CameraMetadata.CONTROL_AE_MODE_OFF }
            ?: (loop != null)
        val physical = activePhysical(result)
        noteFlicker(result)
        val l = loop
        var cleared = false
        val step = if (manualFrame && l != null) {
            // The lens in use bounds the loop, and the mains frequency rounds its times.
            manual?.let { m ->
                l.reconfigure(activeLimits(m.limits, physical), flickerHz)?.let {
                    Log.i(TAG, "loop limits ${l.limits}, antibanding ${l.flickerHz} Hz: asks $it")
                    requestExposure(it, flush = false)
                }
            }
            val frame = ExposureLoop.Settings(exposure, sensitivity)
            val (luma, clip) = ExposureLoop.metered(stats, spot)
            val white = luma >= ExposureLoop.CLIP_HIGH
            cleared = lastWhite && !white
            lastWhite = white
            l.onFrame(frame, luma, clip).also { step ->
                step.request?.let { requestExposure(it, flush = ExposureLoop.flushes(frame, it)) }
                if (step.state == ExposureLoop.State.STEADY) saveLastManual(prefs, l.requested)
            }
        } else {
            null
        }
        if (!emit && !cleared) return
        if (!emit) lastEmitMs = SystemClock.elapsedRealtime()
        // Per frame: on a logical multi-camera the aperture changes with the active lens.
        val (aperture, assumed) = ZoomSupport.frameAperture(
            result.get(CaptureResult.LENS_APERTURE), physical?.apertures, listedApertures,
        )
        val reportedZoom = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            result.get(CaptureResult.CONTROL_ZOOM_RATIO)
        } else {
            null
        }
        val zoom = reportedZoom ?: current?.zoom ?: 1f
        val camera = physical?.kind ?: if (current?.wide == true) "wide" else "main"
        // The ranges of the lens in use: a tele may stop short of the logical camera's.
        val ranges = activeLimits(ExposureLoop.Limits(minExposureNs, maxExposureNs, minIso, maxIso), physical)

        val event = mutableMapOf<String, Any>(
            "exposureNs" to exposure,
            "sensitivity" to sensitivity,
            "boost" to (result.get(CaptureResult.CONTROL_POST_RAW_SENSITIVITY_BOOST) ?: 100),
            "aperture" to aperture,
            "apertureAssumed" to assumed,
            "zoom" to zoom.toDouble(),
            "camera" to camera,
            "aeState" to ZoomSupport.aeStateName(result.get(CaptureResult.CONTROL_AE_STATE)),
            "minExposureNs" to ranges.minExposureNs,
            "maxExposureNs" to ranges.maxExposureNs,
            "minIso" to ranges.minIso,
            "maxIso" to ranges.maxIso,
            "frameLuma" to stats.frame,
            "cropLuma" to stats.crop,
            "spotLuma" to stats.spot,
            "histogram" to stats.histogram.toList(),
        )
        event["engine"] = if (manualFrame) "manual" else "ae"
        event["cropClip"] = stats.cropClip
        event["spotClip"] = stats.spotClip
        if (manualFrame) {
            event["tonemap"] = curve.name
            curve.gamma?.let { event["toneGamma"] = it }
        }
        if (step != null && l != null) {
            event["flickerHz"] = l.flickerHz
            event["requestedExposureNs"] = l.requested.exposureNs
            event["requestedSensitivity"] = l.requested.iso
            event["loop"] = step.state.name.lowercase()
            event["atMinExposure"] = step.atMin
            event["atMaxExposure"] = step.atMax
        }
        mainHandler.post { onStats(event) }
    }

    /**
     * Camera thread. The physical camera behind [result] on a logical multi-camera; null where
     * the phone does not say. Looked up once per camera.
     */
    private fun activePhysical(result: CaptureResult): Physical? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val id = result.get(CaptureResult.LOGICAL_MULTI_CAMERA_ACTIVE_PHYSICAL_ID) ?: return null
        return physicals.getOrPut(id) {
            try {
                val ch = manager.getCameraCharacteristics(id)
                val kind = ZoomSupport.cameraKind(eqFocal(ch), mainEq)
                val exposure = ch.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
                val iso = ch.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
                Log.i(TAG, "physical camera $id: ${kind ?: "unknown"}, t $exposure ns, ISO $iso")
                Physical(kind, ch.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES), exposure, iso)
            } catch (e: Exception) {
                Physical(null, null, null, null)
            }
        }
    }

    /** [limits] within the [physical] camera's ranges, where it lists them; see [ExposureLoop.Limits.within]. */
    private fun activeLimits(limits: ExposureLoop.Limits, physical: Physical?): ExposureLoop.Limits {
        val e = physical?.exposure ?: return limits
        val i = physical.iso ?: return limits
        return limits.within(e.lower, e.upper, i.lower, i.upper)
    }

    /** Mains frequency for antibanding: the one a camera last detected, else the time zone's. */
    private var flickerHz = detectedFlicker ?: Flicker.fromTimeZone(TimeZone.getDefault().id)

    /** Camera thread: takes the mains frequency from [result] when the camera detected one. */
    private fun noteFlicker(result: CaptureResult) {
        val hz = Flicker.fromSceneFlicker(result.get(CaptureResult.STATISTICS_SCENE_FLICKER)) ?: return
        detectedFlicker = hz
        if (hz == flickerHz) return
        Log.i(TAG, "scene flicker $hz Hz (was $flickerHz Hz)")
        flickerHz = hz
    }

    /**
     * Switches the engine: [want] true meters with AE off where the camera allows it, false
     * with the phone's AE. Updates the repeating request in place; [onDone] gets the engine in
     * use ("manual" or "ae") on the main thread.
     */
    fun setEngine(want: Boolean, onDone: (String) -> Unit) {
        val posted = handler.post {
            preferManual = want
            val s = session
            val b = request
            if (!closed && mode == Mode.METER && s != null && b != null) {
                try {
                    applyEngine(b, log = true)
                    s.setRepeatingRequest(b.build(), captureCallback, handler)
                } catch (e: Exception) {
                    Log.w(TAG, "engine switch failed", e)
                }
            }
            val engine = if (loop != null) "manual" else "ae"
            mainHandler.post { onDone(engine) }
        }
        if (!posted) onDone(if (want) "manual" else "ae")
    }

    /** Camera thread: what [ch] allows for the manual engine, or null (with [manualWhy]). */
    private fun manualSupport(ch: CameraCharacteristics): Manual? {
        val exposure = ch.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
        val iso = ch.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
        val why = ExposureLoop.unsupportedReason(
            ch.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES),
            ch.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_MODES),
            exposure != null && iso != null && exposure.lower > 0 && iso.lower > 0,
        )
        if (why != null || exposure == null || iso == null) {
            manualWhy = why ?: "no ranges"
            return null
        }
        manualWhy = "MANUAL_SENSOR and AE_MODE_OFF"
        return Manual(
            limits = ExposureLoop.Limits.of(exposure.lower, exposure.upper, iso.lower, iso.upper),
            boostMin = ch.get(CameraCharacteristics.CONTROL_POST_RAW_SENSITIVITY_BOOST_RANGE)?.lower,
            tone = ToneCurve.choose(ch.get(CameraCharacteristics.TONEMAP_AVAILABLE_TONE_MAP_MODES)),
            curvePoints = minOf(ch.get(CameraCharacteristics.TONEMAP_MAX_CURVE_POINTS) ?: 32, 64),
            maxFrameNs = ch.get(CameraCharacteristics.SENSOR_INFO_MAX_FRAME_DURATION),
        )
    }

    /**
     * Camera thread: sets [b] up for the engine in use: AE off with the loop's exposure, the
     * lowest boost and a known tone curve when [preferManual] and the camera allows it; else
     * the phone's AE and the template's tone curve. AF and AWB stay automatic either way.
     */
    private fun applyEngine(b: CaptureRequest.Builder, log: Boolean) {
        val m = manual
        if (!preferManual || m == null) {
            loop = null
            curve = ToneCurve.SRGB
            b.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
            if (m != null) templateTonemap?.let { b.set(CaptureRequest.TONEMAP_MODE, it) }
            if (log) Log.i(TAG, "engine ae: ${if (m == null) manualWhy else "manual engine turned off"}")
            return
        }
        val l = ExposureLoop(m.limits, lastManual(prefs) ?: ExposureLoop.DEFAULT_START, flickerHz)
        loop = l
        b.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_OFF)
        m.boostMin?.let { b.set(CaptureRequest.CONTROL_POST_RAW_SENSITIVITY_BOOST, it) }
        when (m.tone.mode) {
            CameraMetadata.TONEMAP_MODE_GAMMA_VALUE -> {
                b.set(CaptureRequest.TONEMAP_MODE, CameraMetadata.TONEMAP_MODE_GAMMA_VALUE)
                b.set(CaptureRequest.TONEMAP_GAMMA, ToneCurve.GAMMA.toFloat())
            }
            CameraMetadata.TONEMAP_MODE_PRESET_CURVE -> {
                b.set(CaptureRequest.TONEMAP_MODE, CameraMetadata.TONEMAP_MODE_PRESET_CURVE)
                b.set(CaptureRequest.TONEMAP_PRESET_CURVE, CameraMetadata.TONEMAP_PRESET_CURVE_SRGB)
            }
            CameraMetadata.TONEMAP_MODE_CONTRAST_CURVE -> {
                val pts = ToneCurve.srgbCurvePoints(m.curvePoints)
                b.set(CaptureRequest.TONEMAP_MODE, CameraMetadata.TONEMAP_MODE_CONTRAST_CURVE)
                b.set(CaptureRequest.TONEMAP_CURVE, TonemapCurve(pts, pts, pts))
            }
        }
        curve = m.tone.curve
        setExposure(b, l.requested)
        if (log) {
            Log.i(
                TAG,
                "engine manual: $manualWhy; tonemap ${m.tone.why}, linearised as $curve; " +
                    "boost ${m.boostMin ?: "unset"}; t ${m.limits.minExposureNs}..${m.limits.maxExposureNs} ns, " +
                    "ISO ${m.limits.minIso}..${m.limits.maxIso}; antibanding $flickerHz Hz",
            )
        }
    }

    private fun setExposure(b: CaptureRequest.Builder, e: ExposureLoop.Settings) {
        b.set(CaptureRequest.SENSOR_EXPOSURE_TIME, e.exposureNs)
        b.set(CaptureRequest.SENSOR_SENSITIVITY, e.iso)
        val frame = ExposureLoop.frameDuration(e.exposureNs)
        b.set(CaptureRequest.SENSOR_FRAME_DURATION, manual?.maxFrameNs?.let { minOf(frame, it) } ?: frame)
    }

    /**
     * Camera thread: the loop asked for [e]; the repeating request takes it once the captures
     * in flight are done, or at once when [flush] drops them (see [ExposureLoop.flushes]).
     */
    private fun requestExposure(e: ExposureLoop.Settings, flush: Boolean) {
        val s = session ?: return
        val b = request ?: return
        try {
            setExposure(b, e)
            if (flush) s.abortCaptures()
            s.setRepeatingRequest(b.build(), captureCallback, handler)
        } catch (ex: Exception) {
            Log.w(TAG, "exposure request failed", ex)
        }
    }

    private fun fail(message: String) {
        frameWait?.let { settle(it, run = it.onClose) }
        if (closed) return
        mainHandler.post { onError(message) }
    }

    companion object {
        private const val TAG = "GrainCamera"

        /**
         * The manual engine's last steady settings: the next session, and the next launch,
         * start there. Kept in [PREFS] (not backed up: it belongs to this phone's camera).
         */
        @Volatile private var lastManual: ExposureLoop.Settings? = null

        /** The mains frequency a camera last detected in this process; null until one did. */
        @Volatile private var detectedFlicker: Int? = null

        private const val PREFS = "grain_camera"
        private const val KEY_EXPOSURE = "lastExposureNs"
        private const val KEY_ISO = "lastIso"

        private fun lastManual(prefs: SharedPreferences): ExposureLoop.Settings? {
            lastManual?.let { return it }
            val t = prefs.getLong(KEY_EXPOSURE, 0L)
            val iso = prefs.getInt(KEY_ISO, 0)
            if (t <= 0L || iso <= 0) return null
            return ExposureLoop.Settings(t, iso).also { lastManual = it }
        }

        /** Writes only when [s] moved by a step worth taking, not every steady frame. */
        private fun saveLastManual(prefs: SharedPreferences, s: ExposureLoop.Settings) {
            val old = lastManual
            lastManual = s
            if (old != null && ExposureLoop.close(old, s)) return
            prefs.edit().putLong(KEY_EXPOSURE, s.exposureNs).putInt(KEY_ISO, s.iso).apply()
        }

        /** Capture results kept for pairing with their frames. */
        private const val RESULTS_KEPT = 8

        /** Longest wait for a frame at a new zoom ratio before answering anyway. */
        private const val FRAME_WAIT_MS = 500L

        /** Whether [result] was captured at [zoom] (always, where results do not report it). */
        fun zoomReached(result: CaptureResult, zoom: Float): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return true
            val got = result.get(CaptureResult.CONTROL_ZOOM_RATIO) ?: return true
            return zoomClose(got, zoom)
        }

        /** Within 1 % of each other. */
        fun zoomClose(a: Float, b: Float): Boolean = kotlin.math.abs(a - b) <= 0.01f * b

        /** Typical phone main-camera aperture, used when the phone reports none. */
        const val FALLBACK_APERTURE = 1.8

        /** The first positive listed aperture, else [FALLBACK_APERTURE]. */
        fun phoneAperture(available: FloatArray?): Double =
            available?.firstOrNull { it > 0f }?.toDouble() ?: FALLBACK_APERTURE

        /** True when [phoneAperture] uses a reported aperture rather than the fallback. */
        fun hasListedAperture(available: FloatArray?): Boolean =
            available?.any { it > 0f } == true

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
            return SensorRegions(crop, cx, cy, radiusPx / buffer.width, r.spotMetering)
        }
    }
}
