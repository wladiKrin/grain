package io.github.wladikrin.grain.meter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File

/**
 * `grain/meter` method channel (start / startScan / setZoom / stop / setRegions / snapshot /
 * setEngine), the
 * `grain/meter/stats` event channel (METER mode) and the `grain/meter/qr` event channel
 * (SCAN mode). Everything here runs on the main thread.
 */
class MeterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var textures: TextureRegistry
    private var methods: MethodChannel? = null
    private var statsEvents: EventChannel? = null
    private var qrEvents: EventChannel? = null
    private var statsSink: EventChannel.EventSink? = null
    private var qrSink: EventChannel.EventSink? = null

    private var regions = CameraSession.DisplayRegions.DEFAULT

    /** Meter with the manual engine where the camera allows it; `setEngine` turns it off for comparison. */
    private var preferManual = DEFAULT_MANUAL
    private var session: CameraSession? = null
    private var texture: TextureRegistry.SurfaceTextureEntry? = null
    private var ready: Map<String, Any>? = null
    private val pendingStarts = mutableListOf<MethodChannel.Result>()

    /** True while a previous session is still releasing the camera. */
    private var closing = false
    private val afterClose = mutableListOf<() -> Unit>()

    /**
     * Counts deliberate teardowns (stop, mode change, detach). Work deferred across a close
     * (a queued start, a camera-switch reopen, its fallback) captures it first and is dropped,
     * answering "Camera stopped", when it changed meanwhile.
     */
    private var stops = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        textures = binding.textureRegistry
        methods = MethodChannel(binding.binaryMessenger, "grain/meter").also { it.setMethodCallHandler(this) }
        statsEvents = EventChannel(binding.binaryMessenger, "grain/meter/stats").also {
            it.setStreamHandler(sinkHandler { statsSink = it })
        }
        qrEvents = EventChannel(binding.binaryMessenger, "grain/meter/qr").also {
            it.setStreamHandler(sinkHandler { qrSink = it })
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        statsEvents?.setStreamHandler(null)
        qrEvents?.setStreamHandler(null)
        methods = null
        statsEvents = null
        qrEvents = null
        statsSink = null
        qrSink = null
        stops++
        teardown("Engine detached") {}
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(CameraSession.Mode.METER, 1f, result)
            "startScan" -> start(CameraSession.Mode.SCAN, 1f, result)
            "setZoom" -> setZoom(call.argument<Number>("zoom")?.toFloat() ?: 1f, result)
            "setEngine" -> setEngine(call.argument<Boolean>("manual") != false, result)
            "stop" -> {
                stops++
                teardown("Stopped") { result.success(null) }
            }
            "setRegions" -> setRegions(call, result)
            "snapshot" -> snapshot(call.argument<String>("id"), result)
            else -> result.notImplemented()
        }
    }

    /**
     * Opens a session in [mode] at [zoom] (see [CameraSession.setZoom]), or answers the running
     * one's preview map. A running session in the other mode is closed first.
     */
    private fun start(mode: CameraSession.Mode, zoom: Float, result: MethodChannel.Result) {
        if (context.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            result.error("denied", "Camera permission not granted", null)
            return
        }
        if (closing) {
            val gen = stops
            afterClose.add { unlessStopped(gen, result) { start(mode, zoom, result) } }
            return
        }
        val running = session
        if (running != null && running.mode != mode) {
            val gen = ++stops
            teardown("Camera mode changed") { unlessStopped(gen, result) { start(mode, zoom, result) } }
            return
        }
        ready?.let {
            result.success(it)
            return
        }
        pendingStarts.add(result)
        if (running != null) return // Already opening; answered when ready.

        val entry = textures.createSurfaceTexture()
        texture = entry
        var created: CameraSession? = null
        created = CameraSession(
            context,
            entry.surfaceTexture(),
            mode,
            zoom,
            preferManual,
            onReady = { setup -> if (session === created) onSessionReady(entry, setup) },
            onError = { message ->
                if (session === created) {
                    if (ready != null) sinkFor(mode)?.error("camera_error", message, null)
                    teardown(message) {}
                }
            },
            onStats = { stats -> if (session === created) statsSink?.success(stats) },
            onQr = { text -> if (session === created) qrSink?.success(text) },
        ).also {
            it.setRegions(regions)
            session = it
            it.open()
        }
    }

    private fun sinkFor(mode: CameraSession.Mode) =
        if (mode == CameraSession.Mode.SCAN) qrSink else statsSink

    private fun previewMap(entry: TextureRegistry.SurfaceTextureEntry, setup: CameraSession.PreviewSetup) =
        buildMap<String, Any> {
            put("textureId", entry.id())
            put("previewWidth", setup.previewWidth)
            put("previewHeight", setup.previewHeight)
            put("sensorOrientation", setup.sensorOrientation)
            put("phoneEqFocal", setup.phoneEqFocal)
            put("mainEqFocal", setup.mainEqFocal)
            setup.wideEqFocal?.let { put("wideEqFocal", it) }
            put("wide", setup.wide)
            put("zoom", setup.zoom.toDouble())
            put("maxZoom", setup.maxZoom.toDouble())
        }

    private fun onSessionReady(entry: TextureRegistry.SurfaceTextureEntry, setup: CameraSession.PreviewSetup) {
        val info = previewMap(entry, setup)
        ready = info
        val waiting = pendingStarts.toList()
        pendingStarts.clear()
        waiting.forEach { it.success(info) }
    }

    /**
     * Zoom ratios on the main camera (ultra-wide or tele): switched in place, same texture.
     * Separate ultra-wide camera: the session is reopened on the other camera (new texture); if
     * the ultra-wide fails to open, the main camera is reopened so a preview keeps running, and
     * its map is the answer.
     */
    private fun setZoom(want: Float, result: MethodChannel.Result) {
        val s = session
        val entry = texture
        if (s == null || entry == null || ready == null || closing) {
            result.error("camera_error", "Camera not running", null)
            return
        }
        s.setZoom(want) { setup ->
            if (session !== s) {
                result.error("camera_error", "Camera stopped", null)
            } else if (setup != null) {
                previewMap(entry, setup).let {
                    ready = it
                    result.success(it)
                }
            } else {
                val gen = stops
                teardown("Switching camera") { unlessStopped(gen, result) { reopen(s.mode, want, gen, result) } }
            }
        }
    }

    /** Runs [action] unless a deliberate teardown happened since [gen] was read. */
    private fun unlessStopped(gen: Int, result: MethodChannel.Result, action: () -> Unit) {
        if (stops == gen) action() else result.error("camera_error", "Camera stopped", null)
    }

    private fun reopen(mode: CameraSession.Mode, zoom: Float, gen: Int, result: MethodChannel.Result) {
        start(mode, zoom, object : MethodChannel.Result {
            override fun success(value: Any?) = result.success(value)

            override fun error(code: String, message: String?, details: Any?) {
                val failedToOpen = zoom < 1f && code == "camera_error" && stops == gen
                if (failedToOpen) start(mode, 1f, result) else result.error(code, message, details)
            }

            override fun notImplemented() = result.notImplemented()
        })
    }

    /** Releases camera, session, reader and texture; pending starts fail with [reason]. */
    private fun teardown(reason: String, done: () -> Unit) {
        val waiting = pendingStarts.toList()
        pendingStarts.clear()
        val s = session
        val entry = texture
        session = null
        texture = null
        ready = null
        if (s != null) closing = true
        // After the state reset, so a failed start that retries is queued behind the close.
        waiting.forEach { it.error("camera_error", reason, null) }
        if (s == null) {
            if (closing) afterClose.add(done) else done()
            return
        }
        s.close {
            entry?.release()
            closing = false
            done()
            val queued = afterClose.toList()
            afterClose.clear()
            queued.forEach { it() }
        }
    }

    /**
     * JPEG of the running METER stream's next frame at `filesDir/snapshots/<id>.jpg`; answers
     * its path, or null when no METER preview is running (stopped, scanning, switching camera)
     * or the snapshot failed.
     */
    private fun snapshot(id: String?, result: MethodChannel.Result) {
        if (id == null || !SNAPSHOT_ID.matches(id)) {
            result.error("bad_args", "Expected id: a lowercase UUID", null)
            return
        }
        val s = session
        if (s == null || ready == null || closing || s.mode != CameraSession.Mode.METER) {
            result.success(null)
            return
        }
        val dir = File(context.filesDir, "snapshots")
        if (!dir.isDirectory && !dir.mkdirs()) {
            result.success(null)
            return
        }
        s.requestSnapshot(File(dir, "$id.jpg")) { path -> result.success(path) }
    }

    private fun setRegions(call: MethodCall, result: MethodChannel.Result) {
        val crop = call.argument<List<Number>>("crop")
        val spot = call.argument<List<Number>>("spot")
        if (crop == null || crop.size != 4 || spot == null || spot.size != 3) {
            result.error("bad_args", "Expected crop:[l,t,r,b] and spot:[cx,cy,r]", null)
            return
        }
        regions = CameraSession.DisplayRegions(
            RectD(crop[0].toDouble(), crop[1].toDouble(), crop[2].toDouble(), crop[3].toDouble()),
            spot[0].toDouble(), spot[1].toDouble(), spot[2].toDouble(),
            spotMetering = call.argument<Boolean>("spotMetering") == true,
        )
        session?.setRegions(regions)
        result.success(null)
    }

    /**
     * Picks the metering engine for this and later sessions; answers the engine in use
     * ("manual" or "ae"), or the wanted one while no camera runs.
     */
    private fun setEngine(manual: Boolean, result: MethodChannel.Result) {
        preferManual = manual
        val s = session
        if (s == null || s.mode != CameraSession.Mode.METER) {
            result.success(if (manual) "manual" else "ae")
            return
        }
        s.setEngine(manual) { engine -> result.success(engine) }
    }

    private fun sinkHandler(set: (EventChannel.EventSink?) -> Unit) = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) = set(events)

        override fun onCancel(arguments: Any?) = set(null)
    }

    private companion object {
        val SNAPSHOT_ID = Regex("^[0-9a-f-]{36}$")

        /** The engine a fresh app meters with; false forces the phone's AE. */
        const val DEFAULT_MANUAL = true
    }
}
