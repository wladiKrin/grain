package io.github.wladikrin.grain.meter

import android.hardware.camera2.CameraMetadata

/**
 * The mains frequency the manual engine antibands for ([ExposureLoop.antiband]): what the
 * camera reports in STATISTICS_SCENE_FLICKER, else a guess from the time zone. Pure; no
 * Android objects.
 */
object Flicker {
    /** 50 or 60 for a STATISTICS_SCENE_FLICKER value that names one; null for none or unknown. */
    fun fromSceneFlicker(value: Int?): Int? = when (value) {
        CameraMetadata.STATISTICS_SCENE_FLICKER_50HZ -> 50
        CameraMetadata.STATISTICS_SCENE_FLICKER_60HZ -> 60
        else -> null
    }

    /**
     * Time zones outside America on 60 Hz mains (America is 60 Hz but for
     * [FIFTY_HZ_AMERICA]). The rest of the world runs at 50 Hz, and so does all of Japan
     * here: its east, Tokyo included, is 50 Hz.
     */
    private val SIXTY_HZ_ZONES = setOf(
        "Asia/Seoul", "Asia/Taipei", "Asia/Manila", "Asia/Riyadh",
        "Pacific/Guam", "Pacific/Saipan", "Pacific/Honolulu", "Pacific/Majuro", "Pacific/Palau",
        "US/Hawaii", "US/Alaska", "US/Pacific", "US/Mountain", "US/Central", "US/Eastern",
        "Canada/Pacific", "Canada/Mountain", "Canada/Central", "Canada/Eastern", "Canada/Atlantic",
    )

    /** America zones of 50 Hz countries (the south of South America, French Guiana, ...). */
    private val FIFTY_HZ_AMERICA = listOf(
        "America/Argentina", "America/Buenos_Aires", "America/Cordoba", "America/Mendoza",
        "America/Montevideo", "America/Asuncion", "America/Santiago", "America/Punta_Arenas",
        "America/La_Paz", "America/Cayenne", "America/Nuuk", "America/Godthab",
        "America/Scoresbysund", "America/Danmarkshavn", "America/Thule",
        // Caribbean islands on 50 Hz.
        "America/Guadeloupe", "America/Martinique", "America/Barbados", "America/Jamaica",
        "America/Grenada", "America/St_Lucia", "America/St_Vincent", "America/Dominica",
    )

    /** The mains frequency for time zone [id]: 60 Hz in most of America and a few others, else 50 Hz. */
    fun fromTimeZone(id: String?): Int {
        if (id == null) return 50
        if (id in SIXTY_HZ_ZONES) return 60
        if (id.startsWith("America/")) {
            return if (FIFTY_HZ_AMERICA.any { id == it || id.startsWith("$it/") }) 50 else 60
        }
        return 50
    }
}
