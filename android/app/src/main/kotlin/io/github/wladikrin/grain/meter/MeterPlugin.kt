package io.github.wladikrin.grain.meter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * `grain/meter` method channel (start / stop / setRegions) and `grain/meter/stats` event
 * channel. Everything here runs on the main thread.
 */
class MeterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var textures: TextureRegistry
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    private var regions = CameraSession.DisplayRegions.DEFAULT
    private var session: CameraSession? = null
    private var texture: TextureRegistry.SurfaceTextureEntry? = null
    private var ready: Map<String, Any>? = null
    private val pendingStarts = mutableListOf<MethodChannel.Result>()

    /** True while a previous session is still releasing the camera. */
    private var closing = false
    private val afterClose = mutableListOf<() -> Unit>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        textures = binding.textureRegistry
        methods = MethodChannel(binding.binaryMessenger, "grain/meter").also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, "grain/meter/stats").also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        methods = null
        events = null
        sink = null
        teardown("Engine detached") {}
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(result)
            "stop" -> teardown("Stopped") { result.success(null) }
            "setRegions" -> setRegions(call, result)
            else -> result.notImplemented()
        }
    }

    private fun start(result: MethodChannel.Result) {
        if (context.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            result.error("denied", "Camera permission not granted", null)
            return
        }
        if (closing) {
            afterClose.add { start(result) }
            return
        }
        ready?.let {
            result.success(it)
            return
        }
        pendingStarts.add(result)
        if (session != null) return // Already opening; answered when ready.

        val entry = textures.createSurfaceTexture()
        texture = entry
        var created: CameraSession? = null
        created = CameraSession(
            context,
            entry.surfaceTexture(),
            onReady = { setup -> if (session === created) onSessionReady(entry, setup) },
            onError = { message ->
                if (session === created) {
                    if (ready != null) sink?.error("camera_error", message, null)
                    teardown(message) {}
                }
            },
            onStats = { stats -> if (session === created) sink?.success(stats) },
        ).also {
            it.setRegions(regions)
            session = it
            it.open()
        }
    }

    private fun onSessionReady(entry: TextureRegistry.SurfaceTextureEntry, setup: CameraSession.PreviewSetup) {
        val info = mapOf<String, Any>(
            "textureId" to entry.id(),
            "previewWidth" to setup.previewWidth,
            "previewHeight" to setup.previewHeight,
            "sensorOrientation" to setup.sensorOrientation,
            "phoneEqFocal" to setup.phoneEqFocal,
        )
        ready = info
        pendingStarts.forEach { it.success(info) }
        pendingStarts.clear()
    }

    /** Releases camera, session, reader and texture; pending starts fail with [reason]. */
    private fun teardown(reason: String, done: () -> Unit) {
        pendingStarts.forEach { it.error("camera_error", reason, null) }
        pendingStarts.clear()
        val s = session
        val entry = texture
        session = null
        texture = null
        ready = null
        if (s == null) {
            if (closing) afterClose.add(done) else done()
            return
        }
        closing = true
        s.close {
            entry?.release()
            closing = false
            done()
            val queued = afterClose.toList()
            afterClose.clear()
            queued.forEach { it() }
        }
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
        )
        session?.setRegions(regions)
        result.success(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}
