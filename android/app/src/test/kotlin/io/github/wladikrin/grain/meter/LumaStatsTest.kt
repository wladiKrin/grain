package io.github.wladikrin.grain.meter

import org.junit.Assert.assertEquals
import org.junit.Test
import java.nio.ByteBuffer

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

    @Test fun clipSharesCountTopCodes() {
        // Left quarter at 255, the rest at 100: the crop (left half) is half clipped, the spot on
        // the right none, a spot on the left all.
        val w = 40; val h = 40
        val plane = ByteArray(w * h)
        for (y in 0 until h) for (x in 0 until w) plane[y * w + x] = (if (x < 10) 255 else 100).toByte()
        val s = LumaStats.compute(plane, w, h, w, RectD(0.0, 0.0, 0.5, 1.0), 0.75, 0.5, 0.05)
        assertEquals(0.5, s.cropClip, 1e-9)
        assertEquals(0.0, s.spotClip, 1e-9)
        val left = LumaStats.compute(plane, w, h, w, RectD(0.0, 0.0, 0.5, 1.0), 0.125, 0.5, 0.05)
        assertEquals(1.0, left.spotClip, 1e-9)
        // An empty spot takes the nearest pixel, clipped or not.
        assertEquals(1.0, LumaStats.compute(plane, w, h, w, RectD(0.0, 0.0, 1.0, 1.0), 0.1, 0.5, 0.0).spotClip, 0.0)
    }

    @Test fun spotOnDarkSideIsZero() {
        val w = 40; val h = 40
        val plane = ByteArray(w * h)
        for (y in 0 until h) for (x in 0 until w) plane[y * w + x] = (if (x < 20) 0 else 255).toByte()
        val s = LumaStats.compute(plane, w, h, w, RectD(0.0, 0.0, 1.0, 1.0), 0.25, 0.5, 0.05)
        assertEquals(0.0, s.spot, 1e-9)
        assertEquals(0.5, s.crop, 1e-9)
    }

    @Test fun samplingStepKeepsCost() {
        assertEquals(2, LumaStats.samplingStep(320))
        assertEquals(9, LumaStats.samplingStep(1440))
        assertEquals(2, LumaStats.samplingStep(100))
    }

    @Test fun uniformPlaneSameMeansAtAnyStep() {
        val w = 1440; val h = 1080
        val plane = ByteArray(w * h) { 128.toByte() }
        val crop = RectD(0.25, 0.25, 0.75, 0.75)
        val a = LumaStats.compute(plane, w, h, w, crop, 0.5, 0.5, 0.01, step = 2)
        val b = LumaStats.compute(plane, w, h, w, crop, 0.5, 0.5, 0.01, step = 9)
        assertEquals(a.frame, b.frame, 1e-9)
        assertEquals(a.crop, b.crop, 1e-9)
        assertEquals(a.spot, b.spot, 1e-9)
        assertEquals(LumaStats.srgbToLinear(128), b.frame, 1e-9)
        assertEquals(b.histogram.sum(), b.histogram[32])
    }

    @Test fun sparseSamplingAtPreviewSizeMatchesDenseAtAnalysisSize() {
        // The same smooth scene at the old 320×240 analysis size (step 2) and the 1440×1080
        // preview size (samplingStep = 9): means agree within 1 %, histogram sample counts within 5 %.
        fun scene(w: Int, h: Int) = ByteArray(w * h) { i ->
            val x = (i % w + 0.5) / w; val y = (i / w + 0.5) / h
            (40 + 180 * x * (0.5 + 0.5 * y)).toInt().toByte()
        }
        val crop = RectD(0.2, 0.3, 0.7, 0.8)
        val small = LumaStats.compute(scene(320, 240), 320, 240, 320, crop, 0.6, 0.4, 0.03, step = LumaStats.samplingStep(320))
        val big = LumaStats.compute(scene(1440, 1080), 1440, 1080, 1440, crop, 0.6, 0.4, 0.03, step = LumaStats.samplingStep(1440))
        assertEquals(small.frame, big.frame, small.frame * 0.01)
        assertEquals(small.crop, big.crop, small.crop * 0.01)
        assertEquals(small.spot, big.spot, small.spot * 0.01)
        val n = small.histogram.sum().toDouble()
        assertEquals(n, big.histogram.sum().toDouble(), n * 0.05)
    }

    @Test fun byteBufferReadsGiveTheSameStatsAsTheArray() {
        // Padded rows (stride 1456) of a gradient scene; heap, offset and direct buffers.
        val w = 1440; val h = 1080; val stride = 1456
        val plane = ByteArray(stride * h) { i ->
            val x = i % stride; val y = i / stride
            if (x >= w) 77 else (30 + (200 * x / w) * (y + 200) / (h + 200)).toByte()
        }
        val crop = RectD(0.2, 0.3, 0.7, 0.8)
        val step = LumaStats.samplingStep(w)
        val expected = LumaStats.compute(plane, w, h, stride, crop, 0.6, 0.4, 0.03, step)

        val heap = ByteBuffer.wrap(plane)
        assertEquals(expected, LumaStats.compute(heap, w, h, stride, crop, 0.6, 0.4, 0.03, step))
        assertEquals(0, heap.position())

        val direct = ByteBuffer.allocateDirect(plane.size).put(plane).also { it.rewind() }
        assertEquals(expected, LumaStats.compute(direct, w, h, stride, crop, 0.6, 0.4, 0.03, step))

        val shifted = ByteBuffer.allocate(plane.size + 5).also { it.position(5); it.put(plane); it.position(5) }
        assertEquals(expected, LumaStats.compute(shifted, w, h, stride, crop, 0.6, 0.4, 0.03, step))
        // The empty-spot fallback (nearest pixel) also reads through the buffer.
        assertEquals(
            LumaStats.compute(plane, w, h, stride, crop, 0.6, 0.4, 0.0, step).spot,
            LumaStats.compute(shifted, w, h, stride, crop, 0.6, 0.4, 0.0, step).spot,
            0.0,
        )
    }
}
