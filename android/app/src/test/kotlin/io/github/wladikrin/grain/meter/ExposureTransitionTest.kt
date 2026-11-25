package io.github.wladikrin.grain.meter

import io.github.wladikrin.grain.meter.ExposureLoop.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.ln
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * The loop against a simulated camera: a scene that jumps from a dark room to daylight, a
 * pipeline [Sim.depth] frames deep whose frames last as long as their own request's frame
 * duration, and the 60 ms stats throttle. Times are from the light change to the first
 * stats event whose region is below [ExposureLoop.CLIP_HIGH], the first Dart reads.
 *
 * Before the loop ran on every frame (it saw only the throttled ones, waited 6 of them for a
 * frame [ExposureLoop.close] to the request, never dropped captures in flight and stepped
 * 3 EV for any region below [ExposureLoop.CLIP_FULL]), the slowest of eight phases took:
 * EV 3 to 15, 325 ms at depth 4 and 458 ms at depth 6 (mean 296 / 429); on a camera that
 * rounds to 1/3 stops, 658 and 725 ms (mean 629 / 696); EV −2 to 15, 854 and 1204 ms (mean
 * 809 / 1175). Run [report] for the current numbers.
 */
class ExposureTransitionTest {
    // Pixel-like: 1/100000 .. 1 s, ISO 30 .. 6400; the loop stops at 1/4 s.
    private val limits = ExposureLoop.Limits.of(10_000L, 1_000_000_000L, 30, 6400)

    /** Exposure × ISO (ns × ISO) that puts mid grey at 0.18 at [ev], at f/1.7. */
    private fun midProduct(ev: Double) = 1.7 * 1.7 * 100 * 1e9 / 2.0.pow(ev)

    /** A region [depth] stops deep, even in log: its linear luma and clipped share at [s]. */
    private fun region(s: Settings, ev: Double, depth: Double): Pair<Double, Double> {
        val m = 0.18 * s.product / midProduct(ev)
        val n = 41
        var sum = 0.0
        var clipped = 0
        for (k in 0 until n) {
            val v = m * 2.0.pow(depth * (k.toDouble() / (n - 1) - 0.5))
            if (v >= 1.0) clipped++
            sum += min(v, 1.0)
        }
        return sum / n to clipped.toDouble() / n
    }

    private fun third(x: Double) = 2.0.pow((3 * ln(x) / ln(2.0)).roundToInt() / 3.0)

    /** A camera that runs time and ISO only in 1/3-stop steps: its frames rarely match the request. */
    private fun thirdStops(s: Settings) =
        Settings((1e9 * third(s.exposureNs / 1e9)).roundToLong(), (100 * third(s.iso / 100.0)).roundToInt())

    private val exact = { s: Settings -> s }

    /**
     * [readingMs] to the first event Dart reads (region below [ExposureLoop.CLIP_HIGH]), [frames]
     * camera frames until then; [unclippedMs] to the first with at most [ExposureLoop.CLIP_SHARE]
     * clipped; [requests] after the change; [lateRequests] in the 2 s before it and from 2 s after it.
     */
    data class Run(
        val readingMs: Double,
        val frames: Int,
        val unclippedMs: Double,
        val requests: Int,
        val lateRequests: Int,
        val endLuma: Double,
    )

    /** A camera [depth] frames deep, metering a region [spread] stops deep. */
    class Sim(
        val depth: Int = 4,
        val spread: Double = 4.0,
        val camera: (Settings) -> Settings,
        val everyFrame: Boolean = true,
        val flushes: (Settings, Settings) -> Boolean = ExposureLoop::flushes,
    )

    /** The light changes [phaseMs] after the 10 s mark, so the frame it lands on varies. */
    private fun transition(fromEv: Double, toEv: Double, sim: Sim, phaseMs: Double = 0.0): Run {
        val loop = ExposureLoop(limits, ExposureLoop.DEFAULT_START)
        var repeating = loop.requested
        val queue = ArrayDeque<Settings>()
        repeat(sim.depth - 1) { queue.addLast(repeating) }
        val changeAt = 10_000.0 + phaseMs
        var t = 0.0
        var lastEmit = -1e9
        var refill = 0.0
        var ev = fromEv
        var frames = 0
        var requests = 0
        var late = 0
        var reading: Double? = null
        var unclipped: Double? = null
        var readingFrames = 0
        var luma = 0.0
        var lastWhite = false
        while (t < changeAt + 5_000) {
            val s = sim.camera(queue.removeFirst())
            queue.addLast(repeating)
            t += ExposureLoop.frameDuration(s.exposureNs) / 1e6 + refill
            refill = 0.0
            val changed = t >= changeAt
            if (changed) {
                ev = toEv
                frames++
            }
            val (l, clip) = region(s, ev, sim.spread)
            luma = l
            // The first frame no longer white goes to Dart at once.
            val white = l >= ExposureLoop.CLIP_HIGH
            val cleared = sim.everyFrame && lastWhite && !white
            lastWhite = white
            val emit = t - lastEmit >= 60.0 || cleared
            if (emit) lastEmit = t
            if (emit && changed && reading == null && l > ExposureLoop.CLIP_LOW && l < ExposureLoop.CLIP_HIGH) {
                reading = t - changeAt
                readingFrames = frames
            }
            if (emit && changed && unclipped == null && l > ExposureLoop.CLIP_LOW && clip <= ExposureLoop.CLIP_SHARE) {
                unclipped = t - changeAt
            }
            if (!sim.everyFrame && !emit) continue
            val r = loop.onFrame(s, l, clip).request ?: continue
            if (changed) requests++
            if (t > changeAt + 2_000 || (!changed && t > changeAt - 2_000)) late++
            // Dropped captures: the next frame at the new settings comes after a fresh pipeline.
            if (sim.flushes(s, r)) {
                queue.clear()
                repeat(sim.depth - 1) { queue.addLast(r) }
                refill = (sim.depth - 1) * ExposureLoop.frameDuration(r.exposureNs) / 1e6
            }
            repeating = r
        }
        return Run(reading ?: Double.NaN, readingFrames, unclipped ?: Double.NaN, requests, late, luma)
    }

    /** Over eight phases of the light change against frames and throttle: the mean and slowest run. */
    data class Sweep(val meanMs: Double, val meanUnclippedMs: Double, val worst: Run)

    private fun sweep(fromEv: Double, toEv: Double, sim: Sim): Sweep {
        val runs = (0 until 8).map { transition(fromEv, toEv, sim, phaseMs = it * 66.0 / 8) }
        return Sweep(runs.sumOf { it.readingMs } / runs.size, runs.sumOf { it.unclippedMs } / runs.size, runs.maxBy { it.readingMs })
    }

    /**
     * Every phase reads within [withinMs] and is unclipped within [unclippedMs], steady before
     * and after, in the band at the end.
     */
    private fun assertSettles(fromEv: Double, toEv: Double, sim: Sim, withinMs: Double, unclippedMs: Double = withinMs) {
        for (k in 0 until 8) {
            val r = transition(fromEv, toEv, sim, phaseMs = k * 66.0 / 8)
            assertTrue("phase $k: $r", r.readingMs <= withinMs)
            assertTrue("phase $k: $r", r.unclippedMs <= unclippedMs)
            assertEquals("steady before and after, phase $k: $r", 0, r.lateRequests)
            assertTrue("phase $k: $r", r.endLuma > ExposureLoop.BAND_LOW && r.endLuma < ExposureLoop.BAND_HIGH)
        }
    }

    @Test fun darkRoomToDaylight() {
        assertSettles(3.0, 15.0, Sim(depth = 4, camera = exact), 300.0)
        assertSettles(3.0, 15.0, Sim(depth = 6, camera = exact), 435.0)
    }

    /** At 1/5 s a frame, dropping the long captures in flight is what makes it quick; 17 stops take three steps. */
    @Test fun veryDarkRoomToDaylight() {
        assertSettles(-2.0, 15.0, Sim(depth = 4, camera = exact), 550.0)
        assertSettles(-2.0, 15.0, Sim(depth = 6, camera = exact), 700.0)
    }

    /** A camera whose frames never land on the request steps without waiting for the fallback. */
    @Test fun aRoundingCameraDoesNotWaitOutTheFallback() {
        assertSettles(3.0, 15.0, Sim(depth = 4, camera = ::thirdStops), 300.0)
        assertSettles(3.0, 15.0, Sim(depth = 6, camera = ::thirdStops), 435.0)
    }

    /** A region eight stops deep reads early, partly clipped; it is unclipped two steps later. */
    @Test fun aContrastyRegionUnclipsQuickly() {
        assertSettles(3.0, 15.0, Sim(depth = 4, spread = 8.0, camera = exact), 200.0, unclippedMs = 600.0)
    }

    @Test fun daylightToDarkRoomStillSettles() {
        assertSettles(15.0, 3.0, Sim(depth = 4, camera = exact), 1_000.0)
        assertSettles(15.0, -2.0, Sim(depth = 6, camera = ::thirdStops), 3_000.0)
    }

    @Test fun report() {
        for ((name, cam) in listOf("exact" to exact, "thirds" to ::thirdStops)) {
            for ((from, to) in listOf(3.0 to 15.0, -2.0 to 15.0, 15.0 to 3.0)) {
                for (depth in listOf(4, 6)) {
                    for (spread in listOf(4.0, 8.0)) {
                        val r = sweep(from, to, Sim(depth = depth, spread = spread, camera = cam))
                        println("REPORT $name EV $from->$to depth $depth spread $spread: mean ${r.meanMs.toInt()} ms (unclipped ${r.meanUnclippedMs.toInt()}), worst ${r.worst}")
                    }
                }
            }
        }
    }
}
