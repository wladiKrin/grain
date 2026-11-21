package io.github.wladikrin.grain.meter

import kotlin.math.pow

/** Normalized (0..1) rectangle, left/top inclusive, right/bottom exclusive. */
data class RectD(val l: Double, val t: Double, val r: Double, val b: Double)

/** Means of linear luma (0..1) plus a 64-bin histogram of gamma Y over the crop. */
data class Stats(val frame: Double, val crop: Double, val spot: Double, val histogram: IntArray) {
    override fun equals(other: Any?): Boolean =
        other is Stats && frame == other.frame && crop == other.crop && spot == other.spot &&
            histogram.contentEquals(other.histogram)

    override fun hashCode(): Int =
        ((frame.hashCode() * 31 + crop.hashCode()) * 31 + spot.hashCode()) * 31 + histogram.contentHashCode()
}

/** Pure luma statistics of a camera Y plane; no Android types. */
object LumaStats {
    const val HISTOGRAM_BINS = 64

    private val linearLut = DoubleArray(256) { i ->
        val c = i / 255.0
        if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }

    /** sRGB-encoded 8-bit Y to linear light 0..1. */
    fun srgbToLinear(y: Int): Double = linearLut[y.coerceIn(0, 255)]

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
     * Samples every 2nd pixel in each direction of the Y [plane].
     * [crop] and the spot centre are normalized sensor-buffer coordinates; [spotR] is the
     * spot radius as a fraction of the plane [width] (the spot is a circle in pixel space).
     * An empty crop falls back to the frame mean; an empty spot to the nearest pixel.
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
    ): Stats {
        val histogram = IntArray(HISTOGRAM_BINS)
        var frameSum = 0.0
        var frameN = 0
        var cropSum = 0.0
        var cropN = 0
        var spotSum = 0.0
        var spotN = 0

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
                val g = plane[row + px].toInt() and 0xFF
                val lin = linearLut[g]
                frameSum += lin
                frameN++
                if (inCropRow) {
                    val nx = (px + 0.5) / width
                    if (nx >= crop.l && nx < crop.r) {
                        cropSum += lin
                        cropN++
                        histogram[g shr 2]++
                    }
                }
                val dx = px + 0.5 - cx
                if (dx * dx + dy * dy <= r2) {
                    spotSum += lin
                    spotN++
                }
                px += 2
            }
            py += 2
        }

        val frame = if (frameN > 0) frameSum / frameN else 0.0
        val cropMean = if (cropN > 0) cropSum / cropN else frame
        val spot = if (spotN > 0) {
            spotSum / spotN
        } else {
            val sx = cx.toInt().coerceIn(0, width - 1)
            val sy = cy.toInt().coerceIn(0, height - 1)
            linearLut[plane[sy * rowStride + sx].toInt() and 0xFF]
        }
        return Stats(frame, cropMean, spot, histogram)
    }
}
