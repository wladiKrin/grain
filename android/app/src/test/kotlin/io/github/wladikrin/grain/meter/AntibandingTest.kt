package io.github.wladikrin.grain.meter

import android.hardware.camera2.CameraMetadata
import io.github.wladikrin.grain.meter.ExposureLoop.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.roundToLong

class AntibandingTest {
    // Pixel-like: 1/100000 .. 1 s, ISO 30 .. 6400; the loop stops at 1/4 s.
    private val limits = ExposureLoop.Limits.of(10_000L, 1_000_000_000L, 30, 6400)

    private fun ev(a: Double, b: Double) = ln(b / a) / ln(2.0)

    private fun periods(t: Long, hz: Int): Double = t / ExposureLoop.flickerPeriodNs(hz)

    private fun assertWholePeriods(s: Settings, hz: Int) {
        val n = periods(s.exposureNs, hz)
        assertEquals("$s at $hz Hz: $n periods", n, Math.round(n).toDouble(), 1e-6)
    }

    @Test fun thePeriodIsHalfTheMainsCycle() {
        assertEquals(10_000_000.0, ExposureLoop.flickerPeriodNs(50), 1e-6)
        assertEquals(8_333_333.33, ExposureLoop.flickerPeriodNs(60), 0.01)
        assertEquals(0.0, ExposureLoop.flickerPeriodNs(0), 0.0)
    }

    @Test fun noFlickerLeavesTheSplitAlone() {
        val p = 25_000_000.0 * 30
        assertEquals(Settings(25_000_000L, 30), ExposureLoop.split(p, limits))
        assertEquals(Settings(25_000_000L, 30), ExposureLoop.split(p, limits, 0))
    }

    @Test fun atTheLowestIsoTheTimeDropsToWholePeriodsAndIsoTakesTheRest() {
        // 1/40 s at ISO 30 under 50 Hz: 20 ms (30 ms would need ISO 25), ISO 37.5.
        val p = 25_000_000.0 * 30
        val s = ExposureLoop.split(p, limits, 50)
        assertEquals(Settings(20_000_000L, 38), s)
        assertEquals(0.0, ev(p, s.product), 0.02)
    }

    @Test fun theIsoRampMovesTo30msAt50HzAndStaysAt60Hz() {
        val p = 33_333_333.0 * 800
        // 1/30 s is 3.33 periods at 50 Hz: 30 ms, ISO +11 %.
        assertEquals(Settings(30_000_000L, 889), ExposureLoop.split(p, limits, 50))
        // ...and exactly 4 periods at 60 Hz.
        val sixty = ExposureLoop.split(p, limits, 60)
        assertEquals(800, sixty.iso)
        assertWholePeriods(sixty, 60)
    }

    @Test fun atTheHighestIsoTheTimeGoesUpAPeriodInstead() {
        // 125 ms at ISO 6400: 120 ms would need ISO 6667, so 130 ms at ISO 6154.
        val p = 125_000_000.0 * 6400
        val s = ExposureLoop.split(p, limits, 50)
        assertEquals(Settings(130_000_000L, 6154), s)
        assertEquals(0.0, ev(p, s.product), 0.01)
    }

    @Test fun timesOfOnePeriodOrLessStay() {
        // Bright light: nothing to round without an ND filter.
        assertEquals(Settings(5_000_000L, 30), ExposureLoop.split(5_000_000.0 * 30, limits, 50))
        assertEquals(Settings(10_000_000L, 30), ExposureLoop.split(10_000_000.0 * 30, limits, 50))
        assertEquals(Settings(8_000_000L, 30), ExposureLoop.split(8_000_000.0 * 30, limits, 60))
    }

    @Test fun theNearerFittingMultipleWins() {
        // 1/30 s at ISO 6400, the top of the ramp: 30 ms needs ISO 7111 (no), 40 ms ISO 5333.
        val s = ExposureLoop.split(33_333_333.0 * 6400, limits, 50)
        assertEquals(Settings(40_000_000L, 5333), s)
        // 29 ms at a higher ISO: 30 ms is nearer than 20 ms.
        val t = ExposureLoop.antiband(Settings(29_000_000L, 200), 29_000_000.0 * 200, limits, 50)
        assertEquals(Settings(30_000_000L, 193), t)
    }

    @Test fun nothingFitsKeepsTheSplit() {
        // The longest time at the highest ISO: 250 ms is already 25 periods.
        val top = Settings(250_000_000L, 6400)
        assertEquals(top, ExposureLoop.split(1e9 * 6400, limits, 50))
        // A camera whose ISO range is a single value and whose time cannot reach a period more.
        val narrow = ExposureLoop.Limits(10_000L, 15_000_000L, 100, 100)
        assertEquals(
            Settings(15_000_000L, 100),
            ExposureLoop.antiband(Settings(15_000_000L, 100), 15_000_000.0 * 100, narrow, 50),
        )
    }

    /** Across the loop's whole range: whole periods past one period, the product kept within a step. */
    @Test fun everySplitIsWholePeriodsAndKeepsTheExposure() {
        for (hz in listOf(50, 60)) {
            val period = ExposureLoop.flickerPeriodNs(hz)
            var p = limits.minProduct
            while (p <= limits.maxProduct) {
                val plain = ExposureLoop.split(p, limits)
                val s = ExposureLoop.split(p, limits, hz)
                assertTrue("$s", s.exposureNs in limits.minExposureNs..limits.maxExposureNs)
                assertTrue("$s", s.iso in limits.minIso..limits.maxIso)
                if (abs(ev(p, plain.product)) < 0.03) {
                    assertEquals("$hz Hz, product $p: $s", 0.0, ev(p, s.product), ExposureLoop.MIN_STEP_EV / 2)
                }
                // Only the top of the range, where no multiple fits ISO and time, may miss.
                if (plain.exposureNs > period + 1 && plain.exposureNs < 240_000_000L) assertWholePeriods(s, hz)
                p *= 2.0.pow(1 / 7.0)
            }
        }
    }

    @Test fun theLoopRequestsWholePeriods() {
        val loop = ExposureLoop(limits, Settings(33_333_333L, 400), 50)
        assertWholePeriods(loop.requested, 50)
        // A dark frame: two stops up, still whole periods.
        val f = loop.requested
        val up = loop.onFrame(f, 0.045, 0.0).request!!
        assertWholePeriods(up, 50)
        assertEquals(2.0, ev(f.product, up.product), 0.05)
        // The frame at the request, in the band: steady, no new request.
        assertNull(loop.onFrame(up, 0.18, 0.0).request)
    }

    @Test fun aDetectedFrequencyResplitsTheRequestAtTheSameExposure() {
        val loop = ExposureLoop(limits, Settings(33_333_333L, 800), 50)
        assertEquals(Settings(30_000_000L, 889), loop.requested)
        val next = loop.reconfigure(limits, 60)!!
        assertWholePeriods(next, 60)
        assertEquals(next, loop.requested)
        assertEquals(60, loop.flickerHz)
        assertEquals(0.0, ev(30_000_000.0 * 889, next.product), 0.01)
        // Nothing changed: nothing to send.
        assertNull(loop.reconfigure(limits, 60))
    }

    @Test fun antibandingOffAgainGoesBackToTheSmoothTime() {
        val loop = ExposureLoop(limits, Settings(33_333_333L, 800), 50)
        val next = loop.reconfigure(limits, 0)!!
        assertEquals(33_333_333L, next.exposureNs)
        assertEquals(800.0, next.iso.toDouble(), 1.0)
    }

    @Test fun sceneFlickerNamesTheFrequency() {
        assertEquals(50, Flicker.fromSceneFlicker(CameraMetadata.STATISTICS_SCENE_FLICKER_50HZ))
        assertEquals(60, Flicker.fromSceneFlicker(CameraMetadata.STATISTICS_SCENE_FLICKER_60HZ))
        assertNull(Flicker.fromSceneFlicker(CameraMetadata.STATISTICS_SCENE_FLICKER_NONE))
        assertNull(Flicker.fromSceneFlicker(null))
    }

    @Test fun theTimeZoneGuessesTheMains() {
        for (z in listOf("Europe/Berlin", "Europe/London", "Asia/Tokyo", "Australia/Sydney", "Africa/Cairo", "UTC")) {
            assertEquals(z, 50, Flicker.fromTimeZone(z))
        }
        for (z in listOf(
            "America/New_York", "America/Los_Angeles", "America/Toronto", "America/Mexico_City",
            "America/Sao_Paulo", "America/Bogota", "Asia/Seoul", "Asia/Taipei", "Pacific/Honolulu",
            "US/Eastern",
        )) {
            assertEquals(z, 60, Flicker.fromTimeZone(z))
        }
        for (z in listOf("America/Argentina/Buenos_Aires", "America/Santiago", "America/Montevideo", "America/Cayenne")) {
            assertEquals(z, 50, Flicker.fromTimeZone(z))
        }
        assertEquals(50, Flicker.fromTimeZone(null))
    }

    @Test fun roundedPeriodsStayWithinANanosecondOfTheMultiple() {
        // 60 Hz periods are not whole nanoseconds: k periods round to the nearest ns.
        val s = ExposureLoop.split(50_000_000.0 * 6400, limits, 60)
        assertTrue(abs(s.exposureNs - (periods(s.exposureNs, 60).roundToLong() * ExposureLoop.flickerPeriodNs(60))) <= 1.0)
    }
}
