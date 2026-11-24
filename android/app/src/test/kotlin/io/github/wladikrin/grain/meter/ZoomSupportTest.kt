package io.github.wladikrin.grain.meter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ZoomSupportTest {
    @Test fun maxRatioNeedsApi30AndHeadroom() {
        assertEquals(20f, ZoomSupport.maxRatio(34, 20f), 0f)
        assertEquals(1f, ZoomSupport.maxRatio(29, 20f), 0f)
        assertEquals(1f, ZoomSupport.maxRatio(34, null), 0f)
        assertEquals(1f, ZoomSupport.maxRatio(34, 1f), 0f)
        assertEquals(1f, ZoomSupport.maxRatio(34, Float.NaN), 0f)
    }

    @Test fun clampTeleStaysWithinOneAndTheMaximum() {
        assertEquals(4.2f, ZoomSupport.clampTele(4.2, 10f), 1e-6f)
        assertEquals(10f, ZoomSupport.clampTele(16.0, 10f), 0f)
        assertEquals(1f, ZoomSupport.clampTele(0.5, 10f), 0f)
        assertEquals(1f, ZoomSupport.clampTele(3.0, 1f), 0f)
        assertEquals(1f, ZoomSupport.clampTele(Double.NaN, 10f), 0f)
    }

    @Test fun cameraKindByEquivalentFocal() {
        assertEquals("wide", ZoomSupport.cameraKind(13.0, 25.0))
        assertEquals("main", ZoomSupport.cameraKind(24.0, 25.0))
        assertEquals("tele", ZoomSupport.cameraKind(113.0, 25.0))
        assertNull(ZoomSupport.cameraKind(null, 25.0))
        assertNull(ZoomSupport.cameraKind(0.0, 25.0))
    }

    @Test fun frameApertureFallsBackInOrder() {
        assertEquals(2.8 to false, ZoomSupport.frameAperture(2.8f, floatArrayOf(1.7f), floatArrayOf(1.7f)).round())
        assertEquals(2.8 to false, ZoomSupport.frameAperture(null, floatArrayOf(2.8f), floatArrayOf(1.7f)).round())
        assertEquals(1.7 to false, ZoomSupport.frameAperture(null, null, floatArrayOf(1.7f)).round())
        assertEquals(1.8 to true, ZoomSupport.frameAperture(null, floatArrayOf(), null))
        assertEquals(1.8 to true, ZoomSupport.frameAperture(0f, null, null))
    }

    @Test fun aeStateNames() {
        assertEquals("converged", ZoomSupport.aeStateName(2))
        assertEquals("flash_required", ZoomSupport.aeStateName(4))
        assertEquals("unknown", ZoomSupport.aeStateName(null))
        assertEquals("state9", ZoomSupport.aeStateName(9))
    }

    @Test fun describeZoom() {
        assertEquals("zoom ratio 4.20 (eq 105 mm)", ZoomSupport.describeZoom(4.2f, 105.0))
    }

    private fun Pair<Double, Boolean>.round() = (Math.round(first * 100) / 100.0) to second
}
