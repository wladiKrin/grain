package io.github.wladikrin.grain.meter

import android.hardware.camera2.CameraMetadata
import io.github.wladikrin.grain.meter.ExposureLoop.Settings
import io.github.wladikrin.grain.meter.ExposureLoop.State
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.ln

class ExposureLoopTest {
    // Pixel-like: 1/100000 .. 1 s, ISO 30 .. 6400; the loop stops at 1/4 s.
    private val limits = ExposureLoop.Limits.of(10_000L, 1_000_000_000L, 30, 6400)

    private fun ev(a: Settings, b: Settings) = ln(b.product / a.product) / ln(2.0)

    @Test fun limitsCapTheTimeAtAQuarterSecond() {
        assertEquals(250_000_000L, limits.maxExposureNs)
        assertEquals(100_000_000L, ExposureLoop.Limits.of(10_000L, 100_000_000L, 30, 6400).maxExposureNs)
    }

    @Test fun steadyInsideTheBand() {
        val f = Settings(1_000_000L, 30)
        for (luma in listOf(0.06, 0.18, 0.3, 0.49)) {
            val d = ExposureLoop.decide(f, luma, 0.0, limits)
            assertNull("luma $luma", d.request)
            assertEquals(State.STEADY, d.state)
        }
    }

    @Test fun outsideTheBandStepsTowardMidGrey() {
        val f = Settings(1_000_000L, 30)
        val dark = ExposureLoop.decide(f, 0.045, 0.0, limits)
        assertEquals(2.0, ev(f, dark.request!!), 0.02)
        assertEquals(State.SETTLING, dark.state)
        val bright = ExposureLoop.decide(f, 0.72, 0.0, limits)
        assertEquals(-2.0, ev(f, bright.request!!), 0.02)
    }

    @Test fun stepsAreClampedToThreeEv() {
        val f = Settings(1_000_000L, 100)
        val d = ExposureLoop.decide(f, 0.005, 0.0, limits)
        assertEquals(3.0, ev(f, d.request!!), 0.02)
    }

    @Test fun clippedRegionJumpsThreeToSixEvByItsClippedShare() {
        val f = Settings(4_000_000L, 100)
        val hi = ExposureLoop.decide(f, 0.97, 0.0, limits)
        assertEquals(State.CLIPPED, hi.state)
        assertEquals(-3.0, ev(f, hi.request!!), 0.02)
        assertEquals(-4.5, ev(f, ExposureLoop.decide(f, 0.97, 0.5, limits).request!!), 0.02)
        assertEquals(-6.0, ev(f, ExposureLoop.decide(f, 0.97, 1.0, limits).request!!), 0.02)
        val lo = ExposureLoop.decide(f, 0.001, 0.0, limits)
        assertEquals(State.CLIPPED, lo.state)
        assertEquals(3.0, ev(f, lo.request!!), 0.02)
    }

    @Test fun clippedHighlightsStepDownButNotOutOfTheBand() {
        val f = Settings(4_000_000L, 100)
        // 5 % clipped at luma 0.2: one stop down, to 0.1.
        val d = ExposureLoop.decide(f, 0.2, 0.05, limits)
        assertEquals(State.CLIPPED, d.state)
        assertEquals(-1.0, ev(f, d.request!!), 0.02)
        // At 0.1 still clipped: no further step, so a dark scene with a window does not oscillate.
        val at = ExposureLoop.decide(d.request!!, 0.1, 0.05, limits)
        assertNull(at.request)
        assertEquals(State.CLIPPED, at.state)
        // 1 % clipped is not clipped.
        assertNull(ExposureLoop.decide(f, 0.2, 0.01, limits).request)
    }

    @Test fun splitPrefersLowestIsoUpTo1over30() {
        val fast = ExposureLoop.split(1_000_000.0 * 30, limits)
        assertEquals(Settings(1_000_000L, 30), fast)
        val smooth = ExposureLoop.split(33_333_333.0 * 30, limits)
        assertEquals(Settings(33_333_333L, 30), smooth)
    }

    @Test fun splitRaisesIsoBeforeTime() {
        val s = ExposureLoop.split(33_333_333.0 * 800, limits)
        assertEquals(33_333_333L, s.exposureNs)
        assertEquals(800, s.iso)
        val top = ExposureLoop.split(33_333_333.0 * 6400, limits)
        assertEquals(Settings(33_333_333L, 6400), top)
    }

    @Test fun splitLengthensTimeOnlyAtMaxIso() {
        val s = ExposureLoop.split(100_000_000.0 * 6400, limits)
        assertEquals(Settings(100_000_000L, 6400), s)
        // Past the loop's maximum: clamped to 1/4 s at max ISO.
        assertEquals(Settings(250_000_000L, 6400), ExposureLoop.split(1e9 * 6400, limits))
        // Below the minimum: clamped to the shortest time at min ISO.
        assertEquals(Settings(10_000L, 30), ExposureLoop.split(1.0, limits))
    }

    @Test fun limitsGiveTheRangeFlags() {
        val min = Settings(10_000L, 30)
        val over = ExposureLoop.decide(min, 0.98, 0.95, limits)
        assertTrue(over.atMin)
        assertFalse(over.atMax)
        assertNull(over.request)
        assertEquals(State.CLIPPED, over.state)

        val max = Settings(250_000_000L, 6400)
        val under = ExposureLoop.decide(max, 0.001, 0.0, limits)
        assertTrue(under.atMax)
        assertFalse(under.atMin)
        assertNull(under.request)
        assertEquals(State.CLIPPED, under.state)

        val mid = ExposureLoop.decide(Settings(1_000_000L, 100), 0.18, 0.0, limits)
        assertFalse(mid.atMin)
        assertFalse(mid.atMax)
    }

    @Test fun stepsFromTheFrameOwnValuesNotTheLastRequest() {
        val loop = ExposureLoop(limits, Settings(1_000_000L, 30))
        // The frame ran at the request: in band, no step.
        assertNull(loop.onFrame(Settings(1_000_000L, 30), 0.2, 0.0).request)
        // A dark frame: two stops up from that frame's 1 ms.
        val up = loop.onFrame(Settings(1_000_000L, 30), 0.045, 0.0)
        assertEquals(4_000_000L, up.request!!.exposureNs)
        assertEquals(up.request, loop.requested)
        // Old frames still arrive: they measure but the loop waits (settling).
        val old = loop.onFrame(Settings(1_000_000L, 30), 0.045, 0.0)
        assertNull(old.request)
        assertEquals(State.SETTLING, old.state)
        // The frame at the new setting, now bright: the step is taken from its 4 ms.
        val down = loop.onFrame(Settings(4_000_000L, 30), 0.72, 0.0)
        assertEquals(1_000_000.0, down.request!!.exposureNs.toDouble(), 20_000.0)
    }

    @Test fun settlingGivesUpAfterAFewFrames() {
        val loop = ExposureLoop(limits, Settings(1_000_000L, 30))
        loop.onFrame(Settings(1_000_000L, 30), 0.045, 0.0) // asks for 4 ms
        // The camera keeps delivering 1.5 ms (it cannot do 4): after SETTLE_FRAMES it is accepted.
        val frame = Settings(1_500_000L, 30)
        repeat(ExposureLoop.SETTLE_FRAMES) {
            assertEquals(State.SETTLING, loop.onFrame(frame, 0.0675, 0.0).state)
        }
        assertEquals(State.STEADY, loop.onFrame(frame, 0.0675, 0.0).state)
        assertEquals(frame, loop.requested)
    }

    @Test fun aFrameMostOfTheWayToTheRequestShowsIt() {
        val loop = ExposureLoop(limits, Settings(1_000_000L, 30))
        loop.onFrame(Settings(1_000_000L, 30), 0.045, 0.0) // asks for 4 ms
        // 3 ms (the camera rounds): nearer the request than the old 1 ms, so no wait.
        assertEquals(State.STEADY, loop.onFrame(Settings(3_000_000L, 30), 0.135, 0.0).state)
        val old = Settings(1_000_000L, 30)
        val want = Settings(4_000_000L, 30)
        assertTrue(ExposureLoop.shows(Settings(3_000_000L, 30), want, old))
        assertTrue(ExposureLoop.shows(Settings(4_100_000L, 30), want, old))
        assertFalse(ExposureLoop.shows(Settings(1_500_000L, 30), want, old))
        assertFalse(ExposureLoop.shows(old, want, old))
    }

    @Test fun capturesInFlightAreDroppedOnlyLeavingLongFrames() {
        // From 1/5 s down to 1/30 s frames: dropped.
        assertTrue(ExposureLoop.flushes(Settings(200_000_000L, 6400), Settings(33_333_333L, 600)))
        // 1/30 s frames either way, or longer ones: kept.
        assertFalse(ExposureLoop.flushes(Settings(33_333_333L, 1000), Settings(1_000_000L, 30)))
        assertFalse(ExposureLoop.flushes(Settings(50_000_000L, 6400), Settings(33_333_333L, 6400)))
        assertFalse(ExposureLoop.flushes(Settings(33_333_333L, 6400), Settings(200_000_000L, 6400)))
    }

    /** Every frame steps the loop now: a flickering scene inside the band, or a window held at the floor, never asks. */
    @Test fun aSteadySceneNeverAsksOnAnyFrame() {
        val f = Settings(10_000_000L, 100)
        val loop = ExposureLoop(limits, f)
        val rnd = java.util.Random(1)
        repeat(600) {
            val luma = 0.18 * Math.pow(2.0, rnd.nextGaussian() * 0.5).coerceIn(0.4, 2.5)
            assertNull(loop.onFrame(f, luma, 0.0).request)
        }
        // A dark room with a window, clipped at CLIP_FLOOR: no further step either.
        repeat(600) { assertNull(loop.onFrame(f, ExposureLoop.CLIP_FLOOR * (1 + rnd.nextDouble() * 0.05), 0.2).request) }
    }

    @Test fun smallStepsAreNotRequested() {
        val loop = ExposureLoop(limits, Settings(1_000_000L, 30))
        // Just outside the band, but split rounds to the same settings at the minimum.
        val atMin = Settings(10_000L, 30)
        val d = ExposureLoop.decide(atMin, 0.6, 0.0, limits)
        assertNull(d.request)
        assertTrue(d.atMin)
        assertNotNull(loop.requested)
    }

    @Test fun frameDurationCoversTheExposure() {
        assertEquals(33_333_333L, ExposureLoop.frameDuration(1_000_000L))
        assertEquals(250_000_000L, ExposureLoop.frameDuration(250_000_000L))
    }

    @Test fun supportNeedsManualSensorAndAeOff() {
        val caps = intArrayOf(CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR)
        val ae = intArrayOf(CameraMetadata.CONTROL_AE_MODE_ON, CameraMetadata.CONTROL_AE_MODE_OFF)
        assertNull(ExposureLoop.unsupportedReason(caps, ae, true))
        assertNotNull(ExposureLoop.unsupportedReason(intArrayOf(), ae, true))
        assertNotNull(ExposureLoop.unsupportedReason(null, ae, true))
        assertNotNull(ExposureLoop.unsupportedReason(caps, intArrayOf(CameraMetadata.CONTROL_AE_MODE_ON), true))
        assertNotNull(ExposureLoop.unsupportedReason(caps, ae, false))
    }

    @Test fun aWhiteRegionJumpsSixEv() {
        val f = Settings(4_000_000L, 100)
        val d = ExposureLoop.decide(f, 0.995, 1.0, limits)
        assertEquals(State.CLIPPED, d.state)
        assertEquals(-6.0, ev(f, d.request!!), 0.02)
    }

    /**
     * From the default start (about EV 7), a sunny scene about 8.5 stops brighter is measurable
     * after at most two requests, each shown by the next frame. With 3 EV steps it took three.
     */
    @Test fun daylightFromTheDefaultStartTakesTwoRequests() {
        val loop = ExposureLoop(limits, ExposureLoop.DEFAULT_START)
        val start = ExposureLoop.DEFAULT_START.product
        // Mid grey would sit 8.5 stops above the default exposure.
        fun luma(s: Settings) = minOf(1.0, 0.18 * Math.pow(2.0, 8.5) * s.product / start)
        var frame = loop.requested
        var requests = 0
        repeat(10) {
            val l = luma(frame)
            val step = loop.onFrame(frame, l, if (l >= 0.95) 1.0 else 0.0)
            if (l < ExposureLoop.CLIP_HIGH) return@repeat
            assertNotNull(step.request)
            requests++
            frame = step.request!!
        }
        assertTrue("requests $requests", requests <= 2)
        assertTrue(luma(frame) < ExposureLoop.CLIP_HIGH)
    }
}
