package io.github.wladikrin.grain.meter

import java.nio.ByteBuffer
import kotlin.math.max

/** Normalized (0..1) rectangle, left/top inclusive, right/bottom exclusive. */
data class RectD(val l: Double, val t: Double, val r: Double, val b: Double)

/**
 * Means of linear luma (0..1), the shares of crop and spot samples at or above
 * [LumaStats.CLIP_CODE], plus a 64-bin histogram of gamma Y over the crop.
 */
data class Stats(
    val frame: Double,
    val crop: Double,
    val spot: Double,
    val histogram: IntArray,
    val cropClip: Double = 0.0,
    val spotClip: Double = 0.0,
) {
    override fun equals(other: Any?): Boolean =
        other is Stats && frame == other.frame && crop == other.crop && spot == other.spot &&
            cropClip == other.cropClip && spotClip == other.spotClip && histogram.contentEquals(other.histogram)

    override fun hashCode(): Int =
        ((((frame.hashCode() * 31 + crop.hashCode()) * 31 + spot.hashCode()) * 31 + cropClip.hashCode()) * 31 +
            spotClip.hashCode()) * 31 + histogram.contentHashCode()
}

/** Pure luma statistics of a camera Y plane; no Android types. */
object LumaStats {
    const val HISTOGRAM_BINS = 64

    /** 8-bit Y at or above this counts as clipped. */
    const val CLIP_CODE = 250

    /** sRGB-encoded 8-bit Y to linear light 0..1. */
    fun srgbToLinear(y: Int): Double = ToneCurve.SRGB.lut[y.coerceIn(0, 255)]

    /**
     * Maps a normalized point in display (portrait, upright) coordinates to normalized
     * sensor-buffer coordinates. [orientation] is SENSOR_ORIENTATION: the clockwise
     * rotation that makes the sensor image upright on the display.
     */
    fun displayToSensor(x: Double, y: Double, orientation: Int): Pair<Double, Double> =
        when (((orientation % 360) + 360) % 360) {
            90 -> Pair(y, 1.0 - x)
            180 -> Pair(1.0 - x, 1.0 - y)
            270 -> Pair(1.0 - y, x)
            else -> Pair(x, y)
        }

    /**
     * Sampling step for a plane [width] px wide: about 160 samples per row whatever the size,
     * so stats on a 1440 px preview cost the same as every 2nd pixel of a 320 px plane.
     */
    fun samplingStep(width: Int): Int = max(2, width / 160)

    /**
     * Samples every [step]th pixel in each direction of the Y [plane].
     * [crop] and the spot centre are normalized sensor-buffer coordinates; [spotR] is the
     * spot radius as a fraction of the plane [width] (the spot is a circle in pixel space).
     * An empty crop falls back to the frame mean; an empty spot to the nearest pixel.
     * [curve] is the tone curve the ISP encoded Y with; its inverse linearises.
     */
    fun compute(
        plane: ByteArray,
        width: Int,
        height: Int,
        rowStride: Int,
        crop: RectD,
        spotCx: Double,
        spotCy: Double,
        spotR: Double,
        step: Int = 2,
        curve: ToneCurve = ToneCurve.SRGB,
    ): Stats = computeWith(width, height, rowStride, crop, spotCx, spotCy, spotR, step, curve.lut) { plane[it] }

    /**
     * As [compute], reading only the sampled pixels straight from [plane] (absolute reads from
     * its current position, which is left unchanged), so no copy of the whole plane is needed.
     */
    fun compute(
        plane: ByteBuffer,
        width: Int,
        height: Int,
        rowStride: Int,
        crop: RectD,
        spotCx: Double,
        spotCy: Double,
        spotR: Double,
        step: Int = 2,
        curve: ToneCurve = ToneCurve.SRGB,
    ): Stats {
        val base = plane.position()
        return computeWith(width, height, rowStride, crop, spotCx, spotCy, spotR, step, curve.lut) {
            plane.get(base + it)
        }
    }

    private inline fun computeWith(
        width: Int,
        height: Int,
        rowStride: Int,
        crop: RectD,
        spotCx: Double,
        spotCy: Double,
        spotR: Double,
        step: Int,
        linearLut: DoubleArray,
        byteAt: (Int) -> Byte,
    ): Stats {
        require(step >= 1) { "step must be ≥ 1" }
        val histogram = IntArray(HISTOGRAM_BINS)
        var frameSum = 0.0
        var frameN = 0
        var cropSum = 0.0
        var cropN = 0
        var spotSum = 0.0
        var spotN = 0
        var cropClipN = 0
        var spotClipN = 0

        val cx = spotCx * width
        val cy = spotCy * height
        val rPx = spotR * width
        val r2 = rPx * rPx

        var py = 0
        while (py < height) {
            val ny = (py + 0.5) / height
            val inCropRow = ny >= crop.t && ny < crop.b
            val dy = py + 0.5 - cy
            val row = py * rowStride
            var px = 0
            while (px < width) {
                val g = byteAt(row + px).toInt() and 0xFF
                val lin = linearLut[g]
                frameSum += lin
                frameN++
                if (inCropRow) {
                    val nx = (px + 0.5) / width
                    if (nx >= crop.l && nx < crop.r) {
                        cropSum += lin
                        cropN++
                        if (g >= CLIP_CODE) cropClipN++
                        histogram[g shr 2]++
                    }
                }
                val dx = px + 0.5 - cx
                if (dx * dx + dy * dy <= r2) {
                    spotSum += lin
                    spotN++
                    if (g >= CLIP_CODE) spotClipN++
                }
                px += step
            }
            py += step
        }

        val frame = if (frameN > 0) frameSum / frameN else 0.0
        val cropMean = if (cropN > 0) cropSum / cropN else frame
        val cropClip = if (cropN > 0) cropClipN.toDouble() / cropN else 0.0
        var spotClip = if (spotN > 0) spotClipN.toDouble() / spotN else 0.0
        val spot = if (spotN > 0) {
            spotSum / spotN
        } else {
            val sx = cx.toInt().coerceIn(0, width - 1)
            val sy = cy.toInt().coerceIn(0, height - 1)
            val g = byteAt(sy * rowStride + sx).toInt() and 0xFF
            if (g >= CLIP_CODE) spotClip = 1.0
            linearLut[g]
        }
        return Stats(frame, cropMean, spot, histogram, cropClip, spotClip)
    }
}
