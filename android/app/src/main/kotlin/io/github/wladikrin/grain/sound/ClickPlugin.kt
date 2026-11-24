package io.github.wladikrin.grain.sound

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * `grain/click` method channel: `setEnabled {on}` loads or releases the click, `play {strong}` plays it.
 * Played on the media stream, so the media volume applies and a phone on vibrate or silent still
 * clicks (the user turned the click on in the app). `play`
 * never blocks: SoundPool queues the stream on its own thread, and it is a no-op until loaded.
 */
class ClickPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private var pool: SoundPool? = null
    private var soundId = 0

    @Volatile
    private var loaded = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "grain/click").also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        release()
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setEnabled" -> {
                if (call.argument<Boolean>("on") == true) load() else release()
                result.success(null)
            }
            "play" -> {
                play(call.argument<Boolean>("strong") == true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun load() {
        val ctx = context ?: return
        if (pool != null) return
        try {
            val file = File(ctx.cacheDir, "click.wav")
            if (!file.exists()) file.writeBytes(ClickWav.bytes())
            val sp = SoundPool.Builder()
                .setMaxStreams(2)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .build()
            sp.setOnLoadCompleteListener { _, _, status ->
                if (status == 0) loaded = true else Log.w(TAG, "click load failed: $status")
            }
            pool = sp
            soundId = sp.load(file.absolutePath, 1)
        } catch (e: Exception) {
            Log.w(TAG, "click unavailable", e)
            release() // no click is better than a failed dial
        }
    }

    private fun play(strong: Boolean) {
        val sp = pool ?: return
        if (!loaded) return
        val volume = if (strong) 1.0f else 0.55f
        if (sp.play(soundId, volume, volume, 1, 0, 1.0f) == 0) Log.w(TAG, "click play failed")
    }

    private fun release() {
        loaded = false
        pool?.release()
        pool = null
        soundId = 0
    }

    private companion object {
        const val TAG = "GrainClick"
    }
}
