package io.github.wladikrin.grain.meter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Pixel rectangle, left/top inclusive, right/bottom exclusive. */
data class PixelRect(val l: Int, val t: Int, val r: Int, val b: Int) {
    val width get() = r - l
    val height get() = b - t
}

/**
 * Turns one YUV frame into the small upright JPEG kept with a logged frame: the lens crop,
 * rotated by the sensor orientation, long edge at most [MAX_EDGE] px, at the highest of
 * [QUALITIES] that fits [MAX_BYTES]. A manual-engine frame (flat tone curve, exposed for the
 * loop's band or the spot) is first [toneMap]ped to look like a photo. Everything but [encode]
 * and [encodeJpeg] is pure and unit-tested.
 */
object SnapshotEncoder {
    const val MAX_EDGE = 1000
    const val MAX_BYTES = 120_000
    val QUALITIES = intArrayOf(85, 75, 65, 55)

    /** Quality of the intermediate crop JPEG, decoded again right away. */
    private const val CROP_QUALITY = 95

    /** Absorbs float error such as 0.29 * 1000 = 289.99999999999997. */
    private const val EPS = 1e-6

    private fun evenFloor(x: Double): Int = floor(x + EPS).toInt() and 1.inv()

    /**
     * [crop] (normalized sensor-buffer coordinates) in pixels of a [width]×[height] frame:
     * each edge floored to an even pixel (NV21 chroma is 2×2), clamped to the frame, at least 2×2.
     */
    fun cropPixels(crop: RectD, width: Int, height: Int): PixelRect {
        val maxL = (width - 2).coerceAtLeast(0) and 1.inv()
        val maxT = (height - 2).coerceAtLeast(0) and 1.inv()
        val l = evenFloor(crop.l * width).coerceIn(0, maxL)
        val t = evenFloor(crop.t * height).coerceIn(0, maxT)
        val r = evenFloor(crop.r * width).coerceIn(l + 2, max(l + 2, width and 1.inv()))
        val b = evenFloor(crop.b * height).coerceIn(t + 2, max(t + 2, height and 1.inv()))
        return PixelRect(l, t, r, b)
    }

    /**
     * Upright output size (width, height) for a [cropW]×[cropH] sensor crop: swapped for a
     * 90/270 [orientation], long edge scaled down to [MAX_EDGE], rounded, never upscaled.
     */
    fun outputSize(cropW: Int, cropH: Int, orientation: Int): Pair<Int, Int> {
        val quarter = ((orientation % 360) + 360) % 180 != 0
        val w = if (quarter) cropH else cropW
        val h = if (quarter) cropW else cropH
        val long = max(w, h)
        if (long <= MAX_EDGE) return w to h
        val s = MAX_EDGE.toDouble() / long
        return max(1, (w * s).roundToInt()) to max(1, (h * s).roundToInt())
    }

    /** Largest power-of-two decode subsampling that keeps [longEdge] at least [target] px. */
    fun sampleSize(longEdge: Int, target: Int): Int {
        var s = 1
        while (longEdge / (s * 2) >= target) s *= 2
        return s
    }

    /**
     * The first of [QUALITIES] whose [jpeg] output is at most [MAX_BYTES]; the lowest
     * quality's output when none fits.
     */
    fun firstFitting(jpeg: (quality: Int) -> ByteArray): ByteArray {
        var bytes = ByteArray(0)
        for (q in QUALITIES) {
            bytes = jpeg(q)
            if (bytes.size <= MAX_BYTES) break
        }
        return bytes
    }

    /** The crop's mean linear luma is brought to this, mid grey, before the display curve. */
    const val TARGET_GREY = 0.18

    /** The brightness normalisation goes no further than this factor either way. */
    const val MAX_GAIN = 16.0

    /** Scales linear light into [filmic] so mid grey comes out near sRGB's 0.46. */
    private const val FILMIC_EXPOSURE = 0.6

    /**
     * The [filmic] input shown as white: 2.9 stops over mid grey, so a frame's own clipped
     * white is white once its crop was lifted at all, and near it (0.95) when not.
     */
    private const val FILMIC_WHITE = 0.8

    /** Chroma follows the luma change, within these factors, so colour neither fades nor glows. */
    private const val MIN_CHROMA_GAIN = 0.5
    private const val MAX_CHROMA_GAIN = 2.0

    /** Every this many pixels each way are sampled for the crop's mean. */
    private const val MEAN_STEP = 4

    /**
     * A filmic display curve, linear scene light (any value ≥ 0) to display-linear 0..1: a toe
     * that deepens the shadows, a steeper middle and a soft shoulder instead of a hard clip
     * (Narkowicz's ACES fit).
     */
    fun filmic(x: Double): Double {
        val v = max(0.0, x)
        return (v * (2.51 * v + 0.03) / (v * (2.43 * v + 0.59) + 0.14)).coerceIn(0.0, 1.0)
    }

    /** Mean linear luma of [crop] of the NV21 frame's Y (row stride [width]), through [linear]. */
    fun cropMeanLinear(nv21: ByteArray, width: Int, crop: PixelRect, linear: DoubleArray): Double {
        var sum = 0.0
        var n = 0
        var y = crop.t
        while (y < crop.b) {
            var x = crop.l
            val row = y * width
            while (x < crop.r) {
                sum += linear[nv21[row + x].toInt() and 0xFF]
                n++
                x += MEAN_STEP
            }
            y += MEAN_STEP
        }
        return if (n > 0) sum / n else 0.0
    }

    /**
     * The 8-bit Y lookup for a frame encoded with [curve] whose crop averages [mean] linear:
     * linearised, scaled so the mean lands on [TARGET_GREY] (within [MAX_GAIN]), through
     * [filmic] up to [FILMIC_WHITE] and encoded as sRGB.
     */
    fun displayLut(curve: ToneCurve, mean: Double): IntArray {
        val gain = if (mean > 0 && mean.isFinite()) (TARGET_GREY / mean).coerceIn(1 / MAX_GAIN, MAX_GAIN) else MAX_GAIN
        val white = filmic(FILMIC_WHITE)
        return IntArray(256) { y ->
            val display = min(1.0, filmic(curve.lut[y] * gain * FILMIC_EXPOSURE) / white)
            (ToneCurve.SRGB.encode(display) * 255).roundToInt().coerceIn(0, 255)
        }
    }

    /**
     * Rewrites [crop] of the NV21 frame in place through [lut]: Y directly, each V,U pair scaled
     * about neutral by its block's luma change (within [MIN_CHROMA_GAIN]..[MAX_CHROMA_GAIN]).
     * Pixels outside [crop] are left alone; [crop] edges are even, as [cropPixels] gives them.
     */
    fun applyLut(nv21: ByteArray, width: Int, height: Int, crop: PixelRect, lut: IntArray) {
        val chromaGain = DoubleArray(256) { y ->
            ((lut[y] + 1.0) / (y + 1.0)).coerceIn(MIN_CHROMA_GAIN, MAX_CHROMA_GAIN)
        }
        val uv = width * height
        val b = min(crop.b, height)
        val r = min(crop.r, width)
        for (y in crop.t until b) {
            val row = y * width
            val chromaRow = uv + (y / 2) * width
            for (x in crop.l until r) {
                val i = row + x
                val old = nv21[i].toInt() and 0xFF
                if (y % 2 == 0 && x % 2 == 0) {
                    val k = chromaGain[old]
                    val c = chromaRow + x
                    nv21[c] = scaleChroma(nv21[c], k)
                    nv21[c + 1] = scaleChroma(nv21[c + 1], k)
                }
                nv21[i] = lut[old].toByte()
            }
        }
    }

    private fun scaleChroma(c: Byte, k: Double): Byte =
        (128 + ((c.toInt() and 0xFF) - 128) * k).roundToInt().coerceIn(0, 255).toByte()

    /**
     * A manual-engine frame, encoded with [curve], made to look like a photo: [crop]'s own mean
     * normalised to mid grey and a contrasty display curve ([displayLut], [applyLut]). In place.
     */
    fun toneMap(nv21: ByteArray, width: Int, height: Int, crop: PixelRect, curve: ToneCurve) {
        val mean = cropMeanLinear(nv21, width, crop, curve.lut)
        applyLut(nv21, width, height, crop, displayLut(curve, mean))
    }

    /**
     * YUV_420_888 planes to NV21 (full Y, then interleaved V,U). Row strides and the chroma
     * pixel stride come from the Image planes; row padding is skipped.
     */
    fun yuvToNv21(
        width: Int,
        height: Int,
        y: ByteArray,
        yRowStride: Int,
        u: ByteArray,
        v: ByteArray,
        uvRowStride: Int,
        uvPixelStride: Int,
    ): ByteArray {
        require(width % 2 == 0 && height % 2 == 0) { "NV21 needs even dimensions, got ${width}x$height" }
        val cw = width / 2
        val ch = height / 2
        val out = ByteArray(width * height + 2 * cw * ch)
        for (row in 0 until height) System.arraycopy(y, row * yRowStride, out, row * width, width)
        var o = width * height
        for (row in 0 until ch) {
            var i = row * uvRowStride
            for (col in 0 until cw) {
                out[o++] = v[i]
                out[o++] = u[i]
                i += uvPixelStride
            }
        }
        return out
    }

    /**
     * Encodes [crop] of the NV21 frame upright into [out] (see [encodeJpeg], [writeAtomically]).
     */
    fun encode(nv21: ByteArray, width: Int, height: Int, crop: PixelRect, orientation: Int, out: File) =
        writeAtomically(encodeJpeg(nv21, width, height, crop, orientation), out)

    /** The upright JPEG of [crop] of the NV21 frame, at the first of [QUALITIES] that fits. Throws on failure. */
    fun encodeJpeg(nv21: ByteArray, width: Int, height: Int, crop: PixelRect, orientation: Int): ByteArray {
        val cropJpeg = ByteArrayOutputStream().also {
            val rect = Rect(crop.l, crop.t, crop.r, crop.b)
            if (!YuvImage(nv21, ImageFormat.NV21, width, height, null).compressToJpeg(rect, CROP_QUALITY, it)) {
                throw IOException("YUV crop compression failed")
            }
        }.toByteArray()

        val (outW, outH) = outputSize(crop.width, crop.height, orientation)
        val opts = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(max(crop.width, crop.height), max(outW, outH))
        }
        val decoded = BitmapFactory.decodeByteArray(cropJpeg, 0, cropJpeg.size, opts)
            ?: throw IOException("Crop JPEG decode failed")
        val quarter = ((orientation % 360) + 360) % 180 != 0
        // Target size before rotation, in the decoded bitmap's (sensor) orientation.
        val sensorW = if (quarter) outH else outW
        val sensorH = if (quarter) outW else outH
        val matrix = Matrix().apply {
            postScale(sensorW.toFloat() / decoded.width, sensorH.toFloat() / decoded.height)
            postRotate(orientation.toFloat())
        }
        val upright = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        if (upright !== decoded) decoded.recycle()

        return try {
            firstFitting { q ->
                ByteArrayOutputStream().also { upright.compress(Bitmap.CompressFormat.JPEG, q, it) }.toByteArray()
            }
        } finally {
            upright.recycle()
        }
    }

    /**
     * Writes [bytes] to `out.tmp`, syncs it to disk, then renames it to [out], so neither a
     * reader nor a power loss leaves half a file at [out]. The tmp file is removed on failure.
     */
    fun writeAtomically(bytes: ByteArray, out: File) {
        out.parentFile?.mkdirs()
        val tmp = File(out.path + ".tmp")
        try {
            FileOutputStream(tmp).use {
                it.write(bytes)
                it.fd.sync()
            }
            if (!tmp.renameTo(out)) throw IOException("Rename to ${out.name} failed")
        } catch (e: Exception) {
            tmp.delete()
            throw e
        }
    }
}
