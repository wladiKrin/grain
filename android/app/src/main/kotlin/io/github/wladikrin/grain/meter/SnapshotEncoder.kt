package io.github.wladikrin.grain.meter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.roundToInt

/** Pixel rectangle, left/top inclusive, right/bottom exclusive. */
data class PixelRect(val l: Int, val t: Int, val r: Int, val b: Int) {
    val width get() = r - l
    val height get() = b - t
}

/**
 * Turns one YUV frame into the small upright JPEG kept with a logged frame: the lens crop,
 * rotated by the sensor orientation, long edge at most [MAX_EDGE] px, at the highest of
 * [QUALITIES] that fits [MAX_BYTES]. Everything but [encode] is pure and unit-tested.
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
     * Encodes [crop] of the NV21 frame upright into [out] (written to `out.tmp`, then renamed,
     * so a reader never sees half a file). Throws on failure; the tmp file is removed.
     */
    fun encode(nv21: ByteArray, width: Int, height: Int, crop: PixelRect, orientation: Int, out: File) {
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

        val bytes = try {
            firstFitting { q ->
                ByteArrayOutputStream().also { upright.compress(Bitmap.CompressFormat.JPEG, q, it) }.toByteArray()
            }
        } finally {
            upright.recycle()
        }

        out.parentFile?.mkdirs()
        val tmp = File(out.path + ".tmp")
        try {
            tmp.writeBytes(bytes)
            if (!tmp.renameTo(out)) throw IOException("Rename to ${out.name} failed")
        } catch (e: Exception) {
            tmp.delete()
            throw e
        }
    }
}
