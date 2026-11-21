package io.github.wladikrin.grain.location

/** Picks among location fixes without touching the Android framework (unit-testable). */
object LocationPick {
    data class Fix(val lat: Double, val lon: Double, val accuracy: Float?, val timeMs: Long)

    /**
     * The newest fix no older than [maxAgeMs] at [nowMs]. Equal times: the smaller accuracy value
     * (a fix without accuracy loses to one with it). Null when none is recent enough.
     */
    fun freshest(fixes: List<Fix>, nowMs: Long, maxAgeMs: Long): Fix? =
        fixes
            .filter { nowMs - it.timeMs <= maxAgeMs }
            .sortedWith(
                compareByDescending<Fix> { it.timeMs }.thenBy { it.accuracy ?: Float.MAX_VALUE },
            )
            .firstOrNull()
}
