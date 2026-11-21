package io.github.wladikrin.grain.meter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WideSupportTest {
    @Test fun prefersZoomRatioOnApi30() {
        assertEquals(Wide.ZoomRatio(0.5f, 12.5), WideSupport.choose(25.0, 0.5f, 34, listOf("2" to 13.0)))
    }

    @Test fun fallsBackToSeparateCamera() {
        assertEquals(Wide.Camera("2", 13.0), WideSupport.choose(25.0, null, 29, listOf("2" to 13.0, "3" to 70.0)))
    }

    @Test fun noUltraWide() {
        assertNull(WideSupport.choose(25.0, 1.0f, 34, listOf("3" to 70.0)))
    }

    @Test fun zoomRatioIgnoredBelowApi30() {
        assertEquals(Wide.Camera("2", 13.0), WideSupport.choose(25.0, 0.5f, 29, listOf("2" to 13.0)))
    }

    @Test fun picksTheWidestCameraUnderTheThreshold() {
        // 20.5 is not below 0.8 × 25 = 20; of 13 and 16 the widest wins.
        assertEquals(
            Wide.Camera("4", 13.0),
            WideSupport.choose(25.0, null, 34, listOf("5" to 20.5, "2" to 16.0, "4" to 13.0)),
        )
        assertNull(WideSupport.choose(25.0, null, 34, listOf("5" to 20.0)))
    }
}
