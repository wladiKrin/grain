package io.github.wladikrin.grain.meter

import android.hardware.camera2.CameraMetadata
import java.util.Locale

/** Pure helpers for the main camera's tele zoom and the stats log; no Android objects. */
object ZoomSupport {
    /** A physical camera counts as tele above this multiple of the main eq. focal. */
    private const val TELE_FACTOR = 1.5

    /** Same threshold as [WideSupport] for the ultra-wide. */
    private const val WIDE_FACTOR = 0.8

    /**
     * Largest CONTROL_ZOOM_RATIO the main camera takes: the range's [upper] bound on API ≥ 30,
     * else 1 (no camera zoom).
     */
    fun maxRatio(sdk: Int, upper: Float?): Float =
        if (sdk >= 30 && upper != null && upper.isFinite() && upper > 1f) upper else 1f

    /** [want] within 1..[top]; 1 for a non-finite [want]. */
    fun clampTele(want: Double, top: Float): Float =
        if (want.isFinite()) want.toFloat().coerceIn(1f, maxOf(1f, top)) else 1f

    /** "wide", "main" or "tele" for a camera of eq. focal [eq]; null when unknown. */
    fun cameraKind(eq: Double?, mainEq: Double): String? = when {
        eq == null || !eq.isFinite() || eq <= 0 -> null
        eq < WIDE_FACTOR * mainEq -> "wide"
        eq > TELE_FACTOR * mainEq -> "tele"
        else -> "main"
    }

    /**
     * The aperture for a frame: the one it [reported], else the active physical camera's first
     * listed one, else the opened camera's, else [CameraSession.FALLBACK_APERTURE]. The flag
     * says whether it is that fallback.
     */
    fun frameAperture(reported: Float?, physical: FloatArray?, listed: FloatArray?): Pair<Double, Boolean> {
        if (reported != null && reported > 0f) return reported.toDouble() to false
        if (CameraSession.hasListedAperture(physical)) return CameraSession.phoneAperture(physical) to false
        if (CameraSession.hasListedAperture(listed)) return CameraSession.phoneAperture(listed) to false
        return CameraSession.FALLBACK_APERTURE to true
    }

    /** CONTROL_AE_STATE as a short name. */
    fun aeStateName(state: Int?): String = when (state) {
        null -> "unknown"
        CameraMetadata.CONTROL_AE_STATE_INACTIVE -> "inactive"
        CameraMetadata.CONTROL_AE_STATE_SEARCHING -> "searching"
        CameraMetadata.CONTROL_AE_STATE_CONVERGED -> "converged"
        CameraMetadata.CONTROL_AE_STATE_LOCKED -> "locked"
        CameraMetadata.CONTROL_AE_STATE_FLASH_REQUIRED -> "flash_required"
        CameraMetadata.CONTROL_AE_STATE_PRECAPTURE -> "precapture"
        else -> "state$state"
    }

    /** The log line for a zoom change. */
    fun describeZoom(ratio: Float, eq: Double): String =
        String.format(Locale.US, "zoom ratio %.2f (eq %.0f mm)", ratio, eq)
}
