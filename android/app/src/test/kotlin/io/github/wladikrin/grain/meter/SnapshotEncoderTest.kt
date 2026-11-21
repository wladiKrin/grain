package io.github.wladikrin.grain.meter

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

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

    @Test fun writeAtomicallyLeavesOnlyTheFinalFile() {
        val out = File(tmp.root, "snapshots/f47ac10b-58cc-4372-a567-0e02b2c3d479.jpg")
        SnapshotEncoder.writeAtomically(byteArrayOf(1, 2, 3), out)
        assertArrayEquals(byteArrayOf(1, 2, 3), out.readBytes())
        assertFalse(File(out.path + ".tmp").exists())
        SnapshotEncoder.writeAtomically(byteArrayOf(4), out)
        assertArrayEquals(byteArrayOf(4), out.readBytes())
    }
}
