package io.github.wladikrin.grain.sound

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ClickWavTest {
    @Test fun headerAndLength() {
        val b = ClickWav.bytes()
        assertEquals("RIFF", String(b, 0, 4))
        assertEquals("WAVE", String(b, 8, 4))
        assertEquals("fmt ", String(b, 12, 4))
        assertEquals("data", String(b, 36, 4))
        val bb = ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(b.size - 8, bb.getInt(4))
        assertEquals(16, bb.getInt(16))
        assertEquals(1, bb.getShort(20).toInt()) // PCM
        assertEquals(1, bb.getShort(22).toInt()) // mono
        assertEquals(44100, bb.getInt(24))
        assertEquals(88200, bb.getInt(28))
        assertEquals(2, bb.getShort(32).toInt())
        assertEquals(16, bb.getShort(34).toInt())
        assertEquals(1058, bb.getInt(40)) // 529 samples
        assertEquals(1102, b.size)
    }

    @Test fun otherSampleRate() {
        val b = ClickWav.bytes(48000)
        val bb = ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(48000, bb.getInt(24))
        assertEquals(576 * 2, bb.getInt(40))
        assertEquals(44 + 576 * 2, b.size)
    }

    @Test fun shortDecayingClick() {
        val b = ClickWav.bytes()
        val bb = ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN)
        val n = (b.size - 44) / 2
        val s = IntArray(n) { bb.getShort(44 + it * 2).toInt() }
        val peak = s.maxOf { abs(it) }
        assertTrue("peak $peak", peak in 12000..16384)
        assertTrue("last ${s.last()}", abs(s.last()) < 200)
        assertEquals(0, s[0])
    }
}
