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
}
