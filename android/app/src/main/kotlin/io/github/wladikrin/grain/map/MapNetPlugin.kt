package io.github.wladikrin.grain.map

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InterruptedIOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Semaphore
import okhttp3.Dispatcher
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import org.maplibre.android.MapLibre
import org.maplibre.android.module.http.HttpRequestUtil
import org.maplibre.android.net.ConnectivityReceiver

/**
 * `grain/map_net` method channel: the HTTP client MapLibre loads the map with.
 *
 * `configure {userAgent, offline}` sets the User-Agent every request names Grain with (the tile
 * servers' usage policies ask for one), and whether the map may go online at all: with the
 * Offline style, MapLibre is told there is no network and any request is refused here before it
 * leaves the phone. Each request's end is reported back as `request {url, ok, blocked}` (an ok
 * only after a failure), for the note that the online map is not loading.
 *
 * MapLibre is also told whether it is connected, rather than asking Android: Grain does not hold
 * ACCESS_NETWORK_STATE, which MapLibre's own check needs.
 */
class MapNetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        val ch = MethodChannel(binding.binaryMessenger, "grain/map_net")
        ch.setMethodCallHandler(this)
        channel = ch
        MapNet.report = { url, ok, blocked ->
            main.post {
                channel?.invokeMethod(
                    "request",
                    mapOf("url" to url, "ok" to ok, "blocked" to blocked),
                )
            }
        }
        MapNet.install()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        MapNet.report = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                val ctx = context
                if (ctx == null) {
                    result.error("NO_CONTEXT", "Not attached", null)
                    return
                }
                call.argument<String>("userAgent")?.let { MapNet.userAgent = it }
                val offline = call.argument<Boolean>("offline") != false
                MapNet.offline = offline
                try {
                    MapLibre.getInstance(ctx)
                    ConnectivityReceiver.instance(ctx).setConnected(!offline)
                } catch (e: RuntimeException) {
                    Log.w(TAG, "MapLibre not told the network state", e)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val TAG = "GrainMapNet"
    }
}

/** The client and its state, shared by every map (MapLibre has one client). */
object MapNet {
    @Volatile var userAgent = "Grain (+https://github.com/wladiKrin/grain)"

    /** No request goes out: the Offline style, and until the app has said otherwise. */
    @Volatile var offline = true

    @Volatile var report: ((url: String, ok: Boolean, blocked: Boolean) -> Unit)? = null

    @Volatile private var lastFailed = false
    private var installed = false
    private val gates = ConcurrentHashMap<String, Semaphore>()

    /** Makes MapLibre load everything through [client]. */
    @Synchronized
    fun install() {
        if (installed) return
        installed = true
        HttpRequestUtil.setOkHttpClient(client())
    }

    fun client(): OkHttpClient =
        OkHttpClient.Builder()
            .dispatcher(Dispatcher().apply { maxRequestsPerHost = MapNetPolicy.PER_HOST })
            .addInterceptor(Interceptor { chain -> intercept(chain) })
            .build()

    private fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val url = request.url.toString()
        if (offline) {
            report?.invoke(url, false, true)
            Log.w("GrainMapNet", "refused with the Offline style: $url")
            throw IOException("The Offline map style does not go online")
        }
        val gate = MapNetPolicy.limitKey(request.url.host)?.let { key ->
            gates.getOrPut(key) { Semaphore(MapNetPolicy.PER_SERVER) }
        }
        try {
            gate?.acquire()
        } catch (e: InterruptedException) {
            throw InterruptedIOException("Cancelled while waiting for a connection")
        }
        try {
            val response = chain.proceed(
                request.newBuilder().header("User-Agent", userAgent).build(),
            )
            ended(url, MapNetPolicy.isOk(response.code))
            return response
        } catch (e: IOException) {
            // A request MapLibre gave up (its tile left the screen) is no failure.
            if (!chain.call().isCanceled()) ended(url, false)
            throw e
        } finally {
            gate?.release()
        }
    }

    /** Reports a failure, and an answer only after a failure (the note needs nothing else). */
    private fun ended(url: String, ok: Boolean) {
        if (ok && !lastFailed) return
        lastFailed = !ok
        report?.invoke(url, ok, false)
    }
}

/** How the map's requests are treated, apart from Android for the unit tests. */
object MapNetPolicy {
    /** Connections to one host at a time; OpenFreeMap asks apps for at most four. */
    const val PER_HOST = 4

    /** Connections to a server that asks for at most two (OpenStreetMap, OpenTopoMap). */
    const val PER_SERVER = 2

    /** The server [host] belongs to, if it limits connections over all its hosts. */
    fun limitKey(host: String): String? =
        listOf("openstreetmap.org", "opentopomap.org").firstOrNull {
            host == it || host.endsWith(".$it")
        }

    /** An answer that is not a failure: content, or no tile there. */
    fun isOk(code: Int): Boolean = code in 200..399 || code == 404 || code == 410
}
