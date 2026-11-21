package io.github.wladikrin.grain.sound

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.roundToInt
import kotlin.math.sin

/** The dial click, synthesised: a 12 ms, 2.4 kHz sine with a 2 ms exponential decay (mono, 16-bit PCM WAV). */
object ClickWav {
    private const val HEADER = 44
    private const val DURATION_S = 0.012
    private const val FREQUENCY_HZ = 2400.0
    private const val DECAY_S = 0.002
    private const val AMPLITUDE = 0.5 * 32767

    fun bytes(sampleRate: Int = 44100): ByteArray {
        val samples = (DURATION_S * sampleRate).roundToInt()
        val dataSize = samples * 2
        val buf = ByteBuffer.allocate(HEADER + dataSize).order(ByteOrder.LITTLE_ENDIAN)
        buf.put("RIFF".toByteArray(Charsets.US_ASCII))
        buf.putInt(36 + dataSize)
        buf.put("WAVE".toByteArray(Charsets.US_ASCII))
        buf.put("fmt ".toByteArray(Charsets.US_ASCII))
        buf.putInt(16)
        buf.putShort(1) // PCM
        buf.putShort(1) // mono
        buf.putInt(sampleRate)
        buf.putInt(sampleRate * 2) // byte rate
        buf.putShort(2) // block align
        buf.putShort(16) // bits per sample
        buf.put("data".toByteArray(Charsets.US_ASCII))
        buf.putInt(dataSize)
        for (i in 0 until samples) {
            val t = i.toDouble() / sampleRate
            val v = AMPLITUDE * sin(2 * PI * FREQUENCY_HZ * t) * exp(-t / DECAY_S)
            buf.putShort(v.roundToInt().toShort())
        }
        return buf.array()
    }
}
