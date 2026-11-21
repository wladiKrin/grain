package io.github.wladikrin.grain.meter

import org.junit.Assert.assertEquals
import org.junit.Test

class LumaStatsTest {
    @Test fun linearizesSrgb() {
        assertEquals(0.0, LumaStats.srgbToLinear(0), 1e-9)
        assertEquals(1.0, LumaStats.srgbToLinear(255), 1e-9)
        assertEquals(0.216, LumaStats.srgbToLinear(128), 0.002)
    }

    @Test fun mapsDisplayToSensorAt90() {
        val (u, v) = LumaStats.displayToSensor(0.25, 0.1, 90)
        assertEquals(0.1, u, 1e-9)
        assertEquals(0.75, v, 1e-9)
    }

    @Test fun mapsDisplayToSensorAtOtherOrientations() {
        val (u0, v0) = LumaStats.displayToSensor(0.25, 0.1, 0)
        assertEquals(0.25, u0, 1e-9); assertEquals(0.1, v0, 1e-9)
        val (u180, v180) = LumaStats.displayToSensor(0.25, 0.1, 180)
        assertEquals(0.75, u180, 1e-9); assertEquals(0.9, v180, 1e-9)
        val (u270, v270) = LumaStats.displayToSensor(0.25, 0.1, 270)
        assertEquals(0.9, u270, 1e-9); assertEquals(0.25, v270, 1e-9)
    }

    @Test fun cropAndSpotMeansOnSyntheticImage() {
        // 40×40 plane, rowStride 48 (padding bytes are garbage and must be ignored):
        // left half Y=0, right half Y=255.
        val w = 40; val h = 40; val stride = 48
        val plane = ByteArray(stride * h) { 77 }
        for (y in 0 until h) for (x in 0 until w) {
            plane[y * stride + x] = (if (x < w / 2) 0 else 255).toByte()
        }
        val s = LumaStats.compute(
            plane, w, h, stride,
            crop = RectD(0.5, 0.0, 1.0, 1.0),
            spotCx = 0.75, spotCy = 0.5, spotR = 0.05,
        )
        assertEquals(0.5, s.frame, 1e-9)
        assertEquals(1.0, s.crop, 1e-9)
        assertEquals(1.0, s.spot, 1e-9)
        assertEquals(64, s.histogram.size)
        // Every 2nd pixel in each direction over the right half: 10 × 20 samples.
        assertEquals(200, s.histogram[63])
        assertEquals(200, s.histogram.sum())
    }

    @Test fun spotOnDarkSideIsZero() {
        val w = 40; val h = 40
        val plane = ByteArray(w * h)
        for (y in 0 until h) for (x in 0 until w) plane[y * w + x] = (if (x < 20) 0 else 255).toByte()
        val s = LumaStats.compute(plane, w, h, w, RectD(0.0, 0.0, 1.0, 1.0), 0.25, 0.5, 0.05)
        assertEquals(0.0, s.spot, 1e-9)
        assertEquals(0.5, s.crop, 1e-9)
    }
}
