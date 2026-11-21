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
import android.os.Looper
import android.os.SystemClock
import android.util.Size
import android.view.Surface
import java.util.concurrent.Executor
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * One Camera2 session on the main back camera: a preview into [surfaceTexture] and a small
 * YUV ImageReader whose Y plane feeds [LumaStats]. All camera work runs on a private
 * HandlerThread; [onReady], [onError] and [onStats] are invoked on the main thread.
 */
class CameraSession(
    context: Context,
    private val surfaceTexture: SurfaceTexture,
    private val onReady: (PreviewSetup) -> Unit,
    private val onError: (String) -> Unit,
    private val onStats: (Map<String, Any>) -> Unit,
) {
    data class PreviewSetup(
        val previewWidth: Int,
        val previewHeight: Int,
        val sensorOrientation: Int,
        val phoneEqFocal: Double,
    )

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

    /** Display (portrait) regions as sent by Dart; normalized 0..1, radius relative to crop width. */
    data class DisplayRegions(val crop: RectD, val cx: Double, val cy: Double, val radius: Double) {
        companion object {
            val DEFAULT = DisplayRegions(RectD(0.0, 0.0, 1.0, 1.0), 0.5, 0.5, 0.04)
        }
    }

    fun open() = handler.post { openOnCameraThread() }

    fun setRegions(r: DisplayRegions) {
        displayRegions = r
        regions = toSensor(r, sensorOrientation, readerSize)
    }

    /** Releases device, session and reader, then calls [onClosed] on the main thread. */
    fun close(onClosed: () -> Unit) {
        handler.post {
            closed = true
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
            val id = selectMainBackCamera(manager) ?: return fail("No back camera")
            val ch = manager.getCameraCharacteristics(id)
            val map = ch.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?: return fail("No stream configuration")
            val preview = choosePreviewSize(map.getOutputSizes(SurfaceTexture::class.java))
                ?: return fail("No preview size")
            val yuv = chooseAnalysisSize(map.getOutputSizes(ImageFormat.YUV_420_888))
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
            val setup = PreviewSetup(preview.width, preview.height, sensorOrientation, eqFocal(ch) ?: 0.0)

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
                    configure(camera, surface, r.surface, ch, setup)
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
                        val req = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                            addTarget(preview)
                            addTarget(analysis)
                            set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                            set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
                            val afModes = ch.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)
                            if (afModes?.contains(CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE) == true) {
                                set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                            }
                        }.build()
                        s.setRepeatingRequest(req, captureCallback, handler)
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

    /** Camera thread. Every Image is closed; stats are computed at most 15 times a second. */
    private fun onImage(r: ImageReader) {
        val image = try {
            r.acquireLatestImage()
        } catch (_: IllegalStateException) {
            null
        } ?: return
        image.use { img ->
            if (closed) return
            val now = SystemClock.elapsedRealtime()
            if (now - lastEmitMs < MIN_EVENT_INTERVAL_MS) return
            val result = latest ?: return
            val exposure = result.get(CaptureResult.SENSOR_EXPOSURE_TIME) ?: return
            val sensitivity = result.get(CaptureResult.SENSOR_SENSITIVITY) ?: return
            lastEmitMs = now

            val plane = img.planes[0]
            val buf = plane.buffer
            val n = buf.remaining()
            if (yBuffer.size < n) yBuffer = ByteArray(n)
            buf.get(yBuffer, 0, n)
            val reg = regions
            val stats = LumaStats.compute(
                yBuffer, img.width, img.height, plane.rowStride, reg.crop, reg.cx, reg.cy, reg.r,
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
        private const val MIN_EVENT_INTERVAL_MS = 1000L / 15 + 1
        private const val FULL_FRAME_DIAGONAL_MM = 43.27
        private const val TARGET_EQ_FOCAL_MM = 26.0
        private const val MAX_PREVIEW_EDGE = 1440

        /** 35 mm-equivalent focal length of a camera's first (main) focal length, mm. */
        fun eqFocal(ch: CameraCharacteristics): Double? {
            val f = ch.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.firstOrNull() ?: return null
            val size = ch.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: return null
            val diag = hypot(size.width.toDouble(), size.height.toDouble())
            if (diag <= 0.0) return null
            return f * FULL_FRAME_DIAGONAL_MM / diag
        }

        /** The back camera whose equivalent focal length is closest to 26 mm. */
        fun selectMainBackCamera(manager: CameraManager): String? =
            manager.cameraIdList
                .map { it to manager.getCameraCharacteristics(it) }
                .filter { (_, ch) -> ch.get(CameraCharacteristics.LENS_FACING) == CameraMetadata.LENS_FACING_BACK }
                .minByOrNull { (_, ch) -> eqFocal(ch)?.let { abs(it - TARGET_EQ_FOCAL_MM) } ?: Double.MAX_VALUE }
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

        /** Smallest 4:3 size at least 320×240; else the size closest in area to 320×240. */
        fun chooseAnalysisSize(sizes: Array<Size>?): Size? {
            if (sizes.isNullOrEmpty()) return null
            return sizes.filter { is4by3(it) && max(it.width, it.height) >= 320 }.minByOrNull { it.width * it.height }
                ?: sizes.minByOrNull { abs(it.width * it.height - 320 * 240) }
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
