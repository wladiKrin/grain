package io.github.wladikrin.grain.meter

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import kotlin.math.roundToInt

class SnapshotEncoderTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test fun cropPixelsAlignsToEvenPixels() {
        assertEquals(PixelRect(360, 270, 1080, 810), SnapshotEncoder.cropPixels(RectD(.25, .25, .75, .75), 1440, 1080))
        assertEquals(PixelRect(332, 248, 666, 500), SnapshotEncoder.cropPixels(RectD(.333, .333, .667, .667), 1000, 750))
        assertEquals(PixelRect(0, 0, 1440, 1080), SnapshotEncoder.cropPixels(RectD(-.1, -.1, 1.1, 1.1), 1440, 1080))
    }

    @Test fun cropPixelsIsAtLeastTwoByTwo() {
        assertEquals(PixelRect(500, 374, 502, 376), SnapshotEncoder.cropPixels(RectD(.5, .5, .5, .5), 1000, 750))
        // A degenerate crop at the far edge stays inside the frame.
        assertEquals(PixelRect(998, 748, 1000, 750), SnapshotEncoder.cropPixels(RectD(1.0, 1.0, 1.0, 1.0), 1000, 750))
    }

    @Test fun outputSizeIsUprightAndNeverUpscaled() {
        assertEquals(667 to 1000, SnapshotEncoder.outputSize(1080, 720, 90))
        assertEquals(1000 to 667, SnapshotEncoder.outputSize(1440, 960, 0))
        assertEquals(400 to 600, SnapshotEncoder.outputSize(600, 400, 270))
        assertEquals(1000 to 750, SnapshotEncoder.outputSize(1440, 1080, 180))
    }

    @Test fun yuvToNv21InterleavesVu() {
        val y = ByteArray(8) { it.toByte() }
        val expected = byteArrayOf(0, 1, 2, 3, 4, 5, 6, 7, 20, 10, 21, 11)
        assertArrayEquals(expected, SnapshotEncoder.yuvToNv21(4, 2, y, 4, byteArrayOf(10, 0, 11), byteArrayOf(20, 0, 21), 4, 2))
        assertArrayEquals(expected, SnapshotEncoder.yuvToNv21(4, 2, y, 4, byteArrayOf(10, 11), byteArrayOf(20, 21), 2, 1))
    }

    @Test fun yuvToNv21SkipsRowPadding() {
        // 2×2 Y with row stride 3 (padding byte 99), one chroma sample.
        val y = byteArrayOf(1, 2, 99, 3, 4)
        assertArrayEquals(
            byteArrayOf(1, 2, 3, 4, 20, 10),
            SnapshotEncoder.yuvToNv21(2, 2, y, 3, byteArrayOf(10), byteArrayOf(20), 8, 2),
        )
    }

    @Test fun qualitySteppingStopsAtFirstFit() {
        val tried = mutableListOf<Int>()
        val out = SnapshotEncoder.firstFitting { q -> tried += q; ByteArray(q * 2000) }
        // 85 → 170 000, 75 → 150 000, 65 → 130 000, 55 → 110 000 bytes.
        assertEquals(listOf(85, 75, 65, 55), tried)
        assertEquals(110_000, out.size)

        tried.clear()
        assertEquals(85_000, SnapshotEncoder.firstFitting { q -> tried += q; ByteArray(q * 1000) }.size)
        assertEquals(listOf(85), tried)
    }

    @Test fun qualitySteppingKeepsTheSmallestWhenNothingFits() {
        assertEquals(55 * 3000, SnapshotEncoder.firstFitting { q -> ByteArray(q * 3000) }.size)
    }

    @Test fun sampleSizeKeepsAtLeastTheOutputEdge() {
        assertEquals(1, SnapshotEncoder.sampleSize(1440, 1000))
        assertEquals(2, SnapshotEncoder.sampleSize(2000, 1000))
        assertEquals(2, SnapshotEncoder.sampleSize(3999, 1000))
        assertEquals(4, SnapshotEncoder.sampleSize(4000, 1000))
        assertEquals(1, SnapshotEncoder.sampleSize(600, 600))
    }

    @Test(expected = IllegalArgumentException::class)
    fun yuvToNv21RejectsOddSizes() {
        SnapshotEncoder.yuvToNv21(3, 2, ByteArray(6), 3, ByteArray(2), ByteArray(2), 2, 1)
    }

    private val gamma = ToneCurve.gamma(ToneCurve.GAMMA)

    /** The 8-bit code [curve] encodes linear [lin] as. */
    private fun code(curve: ToneCurve, lin: Double) = (curve.encode(lin) * 255).roundToInt()

    @Test fun midGreyComesOutAsAPhotoMidTone() {
        val lut = SnapshotEncoder.displayLut(gamma, 0.18)
        // sRGB puts mid grey at 0.46 (118); the display curve lands close.
        assertEquals(118.0, lut[code(gamma, 0.18)].toDouble(), 8.0)
        assertTrue(lut[0] <= 2)
        assertTrue(lut[255] >= 240)
        for (y in 1..255) assertTrue("at $y", lut[y] >= lut[y - 1])
    }

    @Test fun theCropIsNormalisedWhereverTheLoopExposedIt() {
        // The same scene exposed for the band's bottom, mid grey and its top: mid grey in the
        // scene comes out the same.
        val want = SnapshotEncoder.displayLut(gamma, 0.18)[code(gamma, 0.18)]
        for (scale in listOf(0.3, 2.5)) {
            val lut = SnapshotEncoder.displayLut(gamma, 0.18 * scale)
            assertEquals("scale $scale", want.toDouble(), lut[code(gamma, 0.18 * scale)].toDouble(), 3.0)
        }
        // A black crop is lifted at most MAX_GAIN.
        val dark = SnapshotEncoder.displayLut(gamma, 0.0)
        assertEquals(SnapshotEncoder.displayLut(gamma, 0.18 / SnapshotEncoder.MAX_GAIN)[40], dark[40])
    }

    @Test fun theDisplayCurveIsContrastier() {
        // A stop either side of mid grey spreads further than a plain sRGB encode.
        val lut = SnapshotEncoder.displayLut(gamma, 0.18)
        val filmic = lut[code(gamma, 0.36)] - lut[code(gamma, 0.09)]
        val srgb = code(ToneCurve.SRGB, 0.36) - code(ToneCurve.SRGB, 0.09)
        assertTrue("$filmic vs $srgb", filmic > srgb + 10)
        // Highlights roll off: two stops over is not yet white, three stops over is.
        assertTrue(lut[code(gamma, 0.18 * 4)] in 200..254)
        assertEquals(255, SnapshotEncoder.displayLut(gamma, 0.09)[code(gamma, 0.09 * 8)])
    }

    @Test fun filmicIsBoundedAndMonotonic() {
        assertEquals(0.0, SnapshotEncoder.filmic(0.0), 1e-3)
        assertEquals(0.0, SnapshotEncoder.filmic(-1.0), 1e-3)
        assertEquals(1.0, SnapshotEncoder.filmic(100.0), 1e-9)
        var last = 0.0
        for (i in 1..400) {
            val v = SnapshotEncoder.filmic(i / 100.0)
            assertTrue(v >= last)
            last = v
        }
    }

    @Test fun cropMeanSamplesOnlyTheCrop() {
        // 8×8 frame: 64 at the left half, 200 at the right; the crop is the right half.
        val nv21 = ByteArray(8 * 8 + 32) { i -> if (i < 64 && i % 8 >= 4) 200.toByte() else 64.toByte() }
        val mean = SnapshotEncoder.cropMeanLinear(nv21, 8, PixelRect(4, 0, 8, 8), gamma.lut)
        assertEquals(gamma.lut[200], mean, 1e-12)
        assertEquals(gamma.lut[64], SnapshotEncoder.cropMeanLinear(nv21, 8, PixelRect(0, 0, 4, 8), gamma.lut), 1e-12)
    }

    @Test fun applyLutMapsLumaAndScalesChromaInsideTheCropOnly() {
        // 4×4 frame, crop the right 2×4; chroma pairs (V,U) per 2×2 block.
        val w = 4
        val h = 4
        val nv21 = ByteArray(w * h + w * h / 2) { 50 }
        for (i in w * h until nv21.size) nv21[i] = if (i % 2 == 0) 148.toByte() else 108.toByte()
        val lut = IntArray(256) { minOf(255, it * 2) } // doubles luma
        SnapshotEncoder.applyLut(nv21, w, h, PixelRect(2, 0, 4, 4), lut)
        for (y in 0 until h) {
            for (x in 0 until w) {
                assertEquals("($x,$y)", if (x >= 2) 100 else 50, nv21[y * w + x].toInt() and 0xFF)
            }
        }
        // Chroma of the crop's blocks: 20 off neutral becomes about 40; outside it stays.
        for (row in 0 until h / 2) {
            val base = w * h + row * w
            assertEquals(148, nv21[base].toInt() and 0xFF)
            assertEquals(108, nv21[base + 1].toInt() and 0xFF)
            assertEquals(168.0, (nv21[base + 2].toInt() and 0xFF).toDouble(), 1.0)
            assertEquals(88.0, (nv21[base + 3].toInt() and 0xFF).toDouble(), 1.0)
        }
    }

    @Test fun neutralGreyStaysNeutralAndChromaGainIsBounded() {
        val w = 2
        val h = 2
        val nv21 = byteArrayOf(2, 2, 2, 2, 128.toByte(), 200.toByte())
        // A huge lift of a near-black pixel: chroma at most doubles.
        SnapshotEncoder.applyLut(nv21, w, h, PixelRect(0, 0, 2, 2), IntArray(256) { 200 })
        assertEquals(128, nv21[4].toInt() and 0xFF)
        assertEquals(255, nv21[5].toInt() and 0xFF) // 128 + 72 × 2, clamped
    }

    @Test fun toneMapBringsADarkFrameToAPhotoMidTone() {
        // A uniform crop exposed 2 stops under mid grey comes out near 118, like a mid grey.
        val w = 8
        val h = 8
        val y = code(gamma, 0.045).toByte()
        val nv21 = ByteArray(w * h + w * h / 2) { i -> if (i < w * h) y else 128.toByte() }
        SnapshotEncoder.toneMap(nv21, w, h, PixelRect(0, 0, 8, 8), gamma)
        assertEquals(118.0, (nv21[0].toInt() and 0xFF).toDouble(), 8.0)
        assertEquals(128, nv21[w * h].toInt() and 0xFF)
    }

    @Test fun writeAtomicallyLeavesOnlyTheFinalFile() {
        val out = File(tmp.root, "snapshots/f47ac10b-58cc-4372-a567-0e02b2c3d479.jpg")
        SnapshotEncoder.writeAtomically(byteArrayOf(1, 2, 3), out)
        assertArrayEquals(byteArrayOf(1, 2, 3), out.readBytes())
        assertFalse(File(out.path + ".tmp").exists())
        SnapshotEncoder.writeAtomically(byteArrayOf(4), out)
        assertArrayEquals(byteArrayOf(4), out.readBytes())
    }
}
