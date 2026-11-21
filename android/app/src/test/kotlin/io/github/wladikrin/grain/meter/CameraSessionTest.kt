package io.github.wladikrin.grain.meter

import org.junit.Assert.assertEquals
import org.junit.Test

class CameraSessionTest {
    @Test fun phoneEqFocalFallsBackToTypicalMainCamera() {
        assertEquals(26.0, CameraSession.phoneEqFocal(null), 1e-9)
        assertEquals(26.0, CameraSession.phoneEqFocal(0.0), 1e-9)
        assertEquals(26.0, CameraSession.phoneEqFocal(Double.NaN), 1e-9)
        assertEquals(24.5, CameraSession.phoneEqFocal(24.5), 1e-9)
    }

    @Test fun apertureFallback() {
        assertEquals(1.8, CameraSession.phoneAperture(null), 0.0)
        assertEquals(1.8, CameraSession.phoneAperture(floatArrayOf()), 0.0)
        assertEquals(1.65, CameraSession.phoneAperture(floatArrayOf(1.65f)), 1e-6)
    }
}
