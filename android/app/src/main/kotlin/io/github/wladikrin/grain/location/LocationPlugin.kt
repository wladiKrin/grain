package io.github.wladikrin.grain.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.github.wladikrin.grain.location.LocationPick.Fix

/**
 * `grain/location` method channel: `current {timeoutMs}` -> {latitude, longitude, accuracy?, timeMs}
 * or null; `error("denied")` without a location permission. Uses the platform LocationManager only
 * (no Play Services). Everything runs on the main thread.
 */
class LocationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private var channel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())

    /** Finishers (with null) of the fresh-fix requests in flight, run on detach. */
    private val cancels = mutableSetOf<(Location?) -> Unit>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "grain/location").also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        cancels.toList().forEach { it(null) }
        cancels.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "current" -> current((call.argument<Number>("timeoutMs") ?: 10_000).toLong(), result)
            else -> result.notImplemented()
        }
    }

    private fun granted(p: String) =
        context.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun current(timeoutMs: Long, result: MethodChannel.Result) {
        if (!granted(Manifest.permission.ACCESS_COARSE_LOCATION) && !granted(Manifest.permission.ACCESS_FINE_LOCATION)) {
            result.error("denied", "Location permission not granted", null)
            return
        }
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (lm == null) {
            result.success(null)
            return
        }
        val now = System.currentTimeMillis()
        val known = lastKnown(lm)
        val recent = LocationPick.freshest(known.map { it.toFix() }, now, RECENT_MS)
        if (recent != null) {
            result.success(recent.toMap())
            return
        }
        val providers = freshProviders().filter { enabled(lm, it) }
        val answer = { fresh: Location? ->
            val fix = fresh?.toFix()
                ?: LocationPick.freshest(known.map { it.toFix() }, System.currentTimeMillis(), STALE_MS)
            result.success(fix?.toMap())
        }
        val deadline = SystemClock.elapsedRealtime() + timeoutMs
        // Each provider gets what is left of the one timeout budget; a failure or an empty
        // answer moves on to the next enabled provider.
        fun attempt(i: Int) {
            val left = deadline - SystemClock.elapsedRealtime()
            if (i >= providers.size || left <= 0) return answer(null)
            requestFresh(lm, providers[i], left) { loc -> if (loc != null) answer(loc) else attempt(i + 1) }
        }
        attempt(0)
    }

    private fun freshProviders(): List<String> = buildList {
        if (Build.VERSION.SDK_INT >= 31) add(LocationManager.FUSED_PROVIDER)
        add(LocationManager.NETWORK_PROVIDER)
        add(LocationManager.GPS_PROVIDER)
    }

    private fun enabled(lm: LocationManager, p: String) = try {
        lm.isProviderEnabled(p)
    } catch (_: Exception) {
        false
    }

    private fun lastKnown(lm: LocationManager): List<Location> {
        val providers = freshProviders() + LocationManager.PASSIVE_PROVIDER
        return providers.mapNotNull { p ->
            try {
                if (enabled(lm, p) || p == LocationManager.PASSIVE_PROVIDER) lm.getLastKnownLocation(p) else null
            } catch (_: SecurityException) {
                null
            } catch (_: IllegalArgumentException) {
                null
            }
        }
    }

    /**
     * Delivers one fix, or null on timeout / failure / detach; [done] runs exactly once. Every
     * way out cancels the system request and the timeout.
     */
    @Suppress("DEPRECATION")
    private fun requestFresh(lm: LocationManager, provider: String, timeoutMs: Long, done: (Location?) -> Unit) {
        var finished = false
        var cancel: () -> Unit = {}
        lateinit var finishRef: (Location?) -> Unit
        val timeout = Runnable { finishRef(null) }
        finishRef = fun(loc: Location?) {
            if (finished) return
            finished = true
            handler.removeCallbacks(timeout)
            cancel()
            cancels.remove(finishRef)
            done(loc)
        }
        val finish = finishRef
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                val signal = CancellationSignal()
                cancel = { signal.cancel() }
                lm.getCurrentLocation(provider, signal, context.mainExecutor) { loc -> finish(loc) }
            } else {
                val listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) = finish(location)
                    override fun onProviderDisabled(p: String) = finish(null)
                    override fun onProviderEnabled(p: String) {}
                    @Deprecated("Deprecated in Java")
                    override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
                }
                cancel = { lm.removeUpdates(listener) }
                lm.requestSingleUpdate(provider, listener, Looper.getMainLooper())
            }
        } catch (_: SecurityException) {
            finish(null)
            return
        } catch (_: IllegalArgumentException) {
            finish(null)
            return
        }
        if (finished) return
        cancels.add(finish)
        handler.postDelayed(timeout, timeoutMs)
    }

    /** Time from the monotonic clock's age, so a skewed wall-clock stamp can't make it look new. */
    private fun Location.toFix() = Fix(
        latitude,
        longitude,
        if (hasAccuracy()) accuracy else null,
        System.currentTimeMillis() - (SystemClock.elapsedRealtimeNanos() - elapsedRealtimeNanos) / 1_000_000,
    )

    private fun Fix.toMap(): Map<String, Any?> = mapOf(
        "latitude" to lat,
        "longitude" to lon,
        "accuracy" to accuracy?.toDouble(),
        "timeMs" to timeMs,
    )

    private companion object {
        const val RECENT_MS = 2 * 60_000L
        const val STALE_MS = 30 * 60_000L
    }
}
