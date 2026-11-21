package io.github.wladikrin.grain.meter

/** How this phone reaches a field of view wider than its main camera. */
sealed class Wide {
    /** The main logical camera zooms out to [ratio] (< 1) via CONTROL_ZOOM_RATIO. */
    data class ZoomRatio(val ratio: Float, val eqFocal: Double) : Wide()

    /** A separate back camera [id] must be opened instead of the main one. */
    data class Camera(val id: String, val eqFocal: Double) : Wide()
}

object WideSupport {
    /** A separate camera counts as ultra-wide only below this fraction of the main eq. focal. */
    private const val SEPARATE_CAMERA_FACTOR = 0.8

    /**
     * [mainEq] is the main camera's 35 mm-equivalent focal, [zoomRatioLower] the lower bound of
     * its CONTROL_ZOOM_RATIO_RANGE (null when unknown), [backCameras] the other back cameras as
     * (id, eq. focal). Prefers the zoom-ratio path on API ≥ 30; else the widest separate camera
     * under 0.8 × [mainEq]; else null (no ultra-wide).
     */
    fun choose(mainEq: Double, zoomRatioLower: Float?, sdk: Int, backCameras: List<Pair<String, Double>>): Wide? {
        if (sdk >= 30 && zoomRatioLower != null && zoomRatioLower < 1f) {
            return Wide.ZoomRatio(zoomRatioLower, mainEq * zoomRatioLower)
        }
        return backCameras
            .filter { (_, eq) -> eq < SEPARATE_CAMERA_FACTOR * mainEq }
            .minByOrNull { (_, eq) -> eq }
            ?.let { (id, eq) -> Wide.Camera(id, eq) }
    }
}
