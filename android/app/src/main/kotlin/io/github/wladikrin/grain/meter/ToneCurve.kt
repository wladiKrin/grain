package io.github.wladikrin.grain.meter

import android.hardware.camera2.CameraMetadata
import kotlin.math.pow

/**
 * The tone curve the ISP applies to the YUV stream, and its inverse for [LumaStats]:
 * sRGB, or a pure power-law [gamma]. Pure; no Android objects.
 */
class ToneCurve private constructor(val name: String, val gamma: Double?) {
    /** Encoded 8-bit Y to linear light 0..1. */
    val lut = DoubleArray(256) { toLinear(it / 255.0) }

    /** Encoded 0..1 to linear 0..1. */
    fun toLinear(c: Double): Double {
        val v = c.coerceIn(0.0, 1.0)
        val g = gamma ?: return if (v <= 0.04045) v / 12.92 else ((v + 0.055) / 1.055).pow(2.4)
        return v.pow(g)
    }

    /** Linear 0..1 to encoded 0..1. */
    fun encode(linear: Double): Double {
        val v = linear.coerceIn(0.0, 1.0)
        val g = gamma ?: return if (v <= 0.0031308) v * 12.92 else 1.055 * v.pow(1 / 2.4) - 0.055
        return v.pow(1 / g)
    }

    override fun toString() = name

    /** TONEMAP_MODE to request ([mode] null: leave the template's) and the curve it gives. */
    data class Choice(val mode: Int?, val curve: ToneCurve, val why: String)

    companion object {
        const val GAMMA = 2.2

        val SRGB = ToneCurve("srgb", null)

        fun gamma(g: Double) = ToneCurve("gamma$g", g)

        /** GAMMA_VALUE 2.2, else the sRGB preset, else an sRGB contrast curve, else untouched (sRGB assumed). */
        fun choose(modes: IntArray?): Choice = when {
            modes == null -> Choice(null, SRGB, "no tonemap modes listed; sRGB assumed")
            CameraMetadata.TONEMAP_MODE_GAMMA_VALUE in modes ->
                Choice(CameraMetadata.TONEMAP_MODE_GAMMA_VALUE, gamma(GAMMA), "GAMMA_VALUE $GAMMA")
            CameraMetadata.TONEMAP_MODE_PRESET_CURVE in modes ->
                Choice(CameraMetadata.TONEMAP_MODE_PRESET_CURVE, SRGB, "PRESET_CURVE sRGB")
            CameraMetadata.TONEMAP_MODE_CONTRAST_CURVE in modes ->
                Choice(CameraMetadata.TONEMAP_MODE_CONTRAST_CURVE, SRGB, "CONTRAST_CURVE sRGB")
            else -> Choice(null, SRGB, "no settable tonemap; sRGB assumed")
        }

        /**
         * [n] (in, out) pairs of the sRGB encode for a TonemapCurve channel, n ≥ 2; inputs
         * spaced quadratically, so the steep shadows get more points.
         */
        fun srgbCurvePoints(n: Int): FloatArray {
            val k = maxOf(2, n)
            return FloatArray(2 * k) { i ->
                val u = (i / 2) / (k - 1.0)
                val x = u * u
                (if (i % 2 == 0) x else SRGB.encode(x)).toFloat()
            }
        }
    }
}
