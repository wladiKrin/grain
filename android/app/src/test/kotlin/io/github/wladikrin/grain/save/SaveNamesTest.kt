package io.github.wladikrin.grain.save

import org.junit.Assert.assertEquals
import org.junit.Test

class SaveNamesTest {
    @Test fun mimeFromExtension() {
        assertEquals("text/csv", SaveNames.mimeFor("roll-1.csv"))
        assertEquals("application/json", SaveNames.mimeFor("roll-1.JSON"))
        assertEquals("application/zip", SaveNames.mimeFor("grain-backup-2026-11-24.zip"))
        assertEquals("application/octet-stream", SaveNames.mimeFor("noext"))
        assertEquals("application/octet-stream", SaveNames.mimeFor("a.xyz"))
    }

    @Test fun cleanStripsPaths() {
        assertEquals("a.csv", SaveNames.clean("/tmp/exports/a.csv"))
        assertEquals("a.csv", SaveNames.clean("..\\a.csv"))
        assertEquals("file", SaveNames.clean("dir/"))
        assertEquals("a b.csv", SaveNames.clean(" a b.csv "))
    }
}
