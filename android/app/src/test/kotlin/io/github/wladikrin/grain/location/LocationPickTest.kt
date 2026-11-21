package io.github.wladikrin.grain.location

import io.github.wladikrin.grain.location.LocationPick.Fix
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LocationPickTest {
    private val now = 1_000_000L
    private val maxAge = 30 * 60_000L

    @Test fun freshestPicksNewestWithinAge() {
        val older = Fix(1.0, 1.0, 50f, now - 60_000)
        val newer = Fix(2.0, 2.0, 2000f, now - 10_000)
        assertEquals(newer, LocationPick.freshest(listOf(older, newer), now, maxAge))
        assertEquals(newer, LocationPick.freshest(listOf(newer, older), now, maxAge))
    }

    @Test fun bothTooOldIsNull() {
        val a = Fix(1.0, 1.0, 50f, now - maxAge - 1)
        val b = Fix(2.0, 2.0, 5f, now - maxAge - 5_000)
        assertNull(LocationPick.freshest(listOf(a, b), now, maxAge))
        assertNull(LocationPick.freshest(emptyList(), now, maxAge))
    }

    @Test fun equalTimesPreferSmallerAccuracy() {
        val coarse = Fix(1.0, 1.0, 2000f, now - 5_000)
        val precise = Fix(2.0, 2.0, 50f, now - 5_000)
        assertEquals(precise, LocationPick.freshest(listOf(coarse, precise), now, maxAge))
        assertEquals(precise, LocationPick.freshest(listOf(precise, coarse), now, maxAge))
    }
}
