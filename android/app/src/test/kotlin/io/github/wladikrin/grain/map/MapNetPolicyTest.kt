package io.github.wladikrin.grain.map

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MapNetPolicyTest {
    @Test fun osmAndOpenTopoMapShareTwoConnectionsOverTheirHosts() {
        assertEquals("openstreetmap.org", MapNetPolicy.limitKey("tile.openstreetmap.org"))
        assertEquals("opentopomap.org", MapNetPolicy.limitKey("a.tile.opentopomap.org"))
        assertEquals("opentopomap.org", MapNetPolicy.limitKey("c.tile.opentopomap.org"))
        assertEquals(2, MapNetPolicy.PER_SERVER)
    }

    @Test fun openFreeMapHasOnlyThePerHostLimit() {
        assertNull(MapNetPolicy.limitKey("tiles.openfreemap.org"))
        assertNull(MapNetPolicy.limitKey("notopenstreetmap.org"))
        assertEquals(4, MapNetPolicy.PER_HOST)
    }

    @Test fun aMissingTileIsNoFailure() {
        assertTrue(MapNetPolicy.isOk(200))
        assertTrue(MapNetPolicy.isOk(204))
        assertTrue(MapNetPolicy.isOk(304))
        assertTrue(MapNetPolicy.isOk(404))
        assertFalse(MapNetPolicy.isOk(403))
        assertFalse(MapNetPolicy.isOk(429))
        assertFalse(MapNetPolicy.isOk(500))
        assertFalse(MapNetPolicy.isOk(503))
    }
}
