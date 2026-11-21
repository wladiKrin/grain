package io.github.wladikrin.grain.location

/** Picks among location fixes without touching the Android framework (unit-testable). */
object LocationPick {
    data class Fix(val lat: Double, val lon: Double, val accuracy: Float?, val timeMs: Long)

    /**
     * The newest fix no older than [maxAgeMs] at [nowMs]. Equal times: the smaller accuracy value
     * (a fix without accuracy loses to one with it). Fixes dated in the future are rejected. Null when none qualifies.
     */
    /** Fixes stamped further ahead than this are clock errors and are dropped. */
    private const val FUTURE_SLACK_MS = 1_000L

    fun freshest(fixes: List<Fix>, nowMs: Long, maxAgeMs: Long): Fix? =
        fixes
            .filter { it.timeMs <= nowMs + FUTURE_SLACK_MS && nowMs - it.timeMs <= maxAgeMs }
            .sortedWith(
                compareByDescending<Fix> { it.timeMs }.thenBy { it.accuracy ?: Float.MAX_VALUE },
            )
            .firstOrNull()
}
