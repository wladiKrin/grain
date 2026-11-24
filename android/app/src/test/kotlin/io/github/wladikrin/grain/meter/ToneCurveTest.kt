package io.github.wladikrin.grain.meter

import android.hardware.camera2.CameraMetadata
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test
import kotlin.math.pow

class ToneCurveTest {
    @Test fun srgbInverse() {
        val c = ToneCurve.SRGB
        assertEquals(0.0, c.lut[0], 1e-9)
        assertEquals(1.0, c.lut[255], 1e-9)
        assertEquals(0.216, c.lut[128], 0.002)
        // The linear toe.
        assertEquals(10 / 255.0 / 12.92, c.lut[10], 1e-9)
    }

    @Test fun gammaInverse() {
        val c = ToneCurve.gamma(2.2)
        assertEquals(0.0, c.lut[0], 1e-9)
        assertEquals(1.0, c.lut[255], 1e-9)
        assertEquals((128 / 255.0).pow(2.2), c.lut[128], 1e-12)
        // Mid grey 0.18 encodes to about 117 with gamma 2.2, 118 with sRGB.
        assertEquals(117.0, 255 * c.encode(0.18), 0.6)
        assertEquals(118.0, 255 * ToneCurve.SRGB.encode(0.18), 0.6)
    }

    @Test fun encodeInvertsToLinear() {
        for (curve in listOf(ToneCurve.SRGB, ToneCurve.gamma(2.2))) {
            for (x in listOf(0.001, 0.01, 0.18, 0.5, 0.9)) {
                assertEquals("$curve $x", x, curve.toLinear(curve.encode(x)), 1e-9)
            }
        }
    }

    @Test fun choosesGammaThenPresetThenContrastCurve() {
        val g = ToneCurve.choose(
            intArrayOf(
                CameraMetadata.TONEMAP_MODE_CONTRAST_CURVE,
                CameraMetadata.TONEMAP_MODE_PRESET_CURVE,
                CameraMetadata.TONEMAP_MODE_GAMMA_VALUE,
            ),
        )
        assertEquals(CameraMetadata.TONEMAP_MODE_GAMMA_VALUE, g.mode)
        assertEquals(2.2, g.curve.gamma!!, 0.0)

        val p = ToneCurve.choose(
            intArrayOf(CameraMetadata.TONEMAP_MODE_CONTRAST_CURVE, CameraMetadata.TONEMAP_MODE_PRESET_CURVE),
        )
        assertEquals(CameraMetadata.TONEMAP_MODE_PRESET_CURVE, p.mode)
        assertSame(ToneCurve.SRGB, p.curve)

        val c = ToneCurve.choose(intArrayOf(CameraMetadata.TONEMAP_MODE_FAST, CameraMetadata.TONEMAP_MODE_CONTRAST_CURVE))
        assertEquals(CameraMetadata.TONEMAP_MODE_CONTRAST_CURVE, c.mode)
        assertSame(ToneCurve.SRGB, c.curve)

        val none = ToneCurve.choose(intArrayOf(CameraMetadata.TONEMAP_MODE_FAST))
        assertNull(none.mode)
        assertSame(ToneCurve.SRGB, none.curve)
        assertNull(ToneCurve.choose(null).mode)
    }

    @Test fun srgbCurvePointsRunFromBlackToWhite() {
        val pts = ToneCurve.srgbCurvePoints(64)
        assertEquals(128, pts.size)
        assertEquals(0f, pts[0], 0f)
        assertEquals(0f, pts[1], 0f)
        assertEquals(1f, pts[126], 1e-6f)
        assertEquals(1f, pts[127], 1e-6f)
        for (i in 2 until pts.size step 2) {
            val x = pts[i].toDouble()
            assertEquals(ToneCurve.SRGB.encode(x), pts[i + 1].toDouble(), 1e-6)
            assert(pts[i] > pts[i - 2])
        }
    }

    @Test fun lumaStatsUsesTheGivenCurve() {
        val w = 20; val h = 20
        val plane = ByteArray(w * h) { 128.toByte() }
        val all = RectD(0.0, 0.0, 1.0, 1.0)
        val srgb = LumaStats.compute(plane, w, h, w, all, 0.5, 0.5, 0.1)
        val gamma = LumaStats.compute(plane, w, h, w, all, 0.5, 0.5, 0.1, curve = ToneCurve.gamma(2.2))
        assertEquals(ToneCurve.SRGB.lut[128], srgb.crop, 1e-12)
        assertEquals((128 / 255.0).pow(2.2), gamma.crop, 1e-12)
        assertEquals((128 / 255.0).pow(2.2), gamma.spot, 1e-12)
        // The histogram bins gamma Y whatever the curve.
        assertEquals(srgb.histogram.toList(), gamma.histogram.toList())
    }
}
