package io.github.wladikrin.grain.save

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException

class SaveIoTest {
    @Test fun wtWhenTheProviderTakesIt() {
        val out = ByteArrayOutputStream()
        val modes = mutableListOf<String>()
        assertSame(out, SaveIo.openTruncating { modes += it; out })
        assertEquals(listOf("wt"), modes)
    }

    @Test fun fallsBackToWAndTruncates() {
        for (rejection in listOf(
            FileNotFoundException("Unsupported mode: wt"),
            IllegalArgumentException("Bad mode"),
            UnsupportedOperationException(),
        )) {
            val f = File.createTempFile("save", ".bin").apply { writeBytes(ByteArray(10) { 7 }) }
            try {
                val modes = mutableListOf<String>()
                SaveIo.openTruncating { mode ->
                    modes += mode
                    if (mode == "wt") throw rejection
                    // A "w" that keeps the old bytes, as some providers do.
                    FileOutputStream(f, true)
                }.use { it.write(byteArrayOf(1, 2)) }
                assertEquals(listOf("wt", "w"), modes)
                assertArrayEquals(byteArrayOf(1, 2), f.readBytes())
            } finally {
                f.delete()
            }
        }
    }

    @Test fun nullFromWtAlsoFallsBack() {
        val out = ByteArrayOutputStream()
        assertSame(out, SaveIo.openTruncating { if (it == "wt") null else out })
    }

    @Test fun noStreamAtAllIsAnError() {
        try {
            SaveIo.openTruncating { null }
            fail()
        } catch (e: IOException) {
            assertEquals("Couldn't open the file to write.", e.message)
        }
    }

    @Test fun saveAllWritesEachInOrder() {
        val written = mutableListOf<String>()
        val docs = SaveIo.saveAll(
            listOf("a.csv", "b.json"),
            create = { "doc:$it" },
            write = { i, d -> written += "$i>$d" },
            delete = { fail() },
            nameOf = { it },
        )
        assertEquals(listOf("doc:a.csv", "doc:b.json"), docs)
        assertEquals(listOf("a.csv>doc:a.csv", "b.json>doc:b.json"), written)
    }

    @Test fun aFailedWriteRemovesEveryDocumentOfTheSave() {
        val deleted = mutableListOf<String>()
        try {
            SaveIo.saveAll(
                listOf("a.csv", "b.json", "c.zip"),
                create = { "doc:$it" },
                write = { i, _ -> if (i == "b.json") throw IOException("No space left") },
                delete = { deleted += it },
                nameOf = { it },
            )
            fail()
        } catch (e: IOException) {
            assertEquals("No space left", e.message)
        }
        // The half-written one too; c.zip was never made.
        assertEquals(listOf("doc:b.json", "doc:a.csv"), deleted)
    }

    @Test fun aFailedCreateRemovesTheEarlierOnesEvenIfDeleteFails() {
        val deleted = mutableListOf<String>()
        try {
            SaveIo.saveAll(
                listOf("a.csv", "b.json"),
                create = { if (it == "b.json") null else "doc:$it" },
                write = { _, _ -> },
                delete = {
                    deleted += it
                    throw UnsupportedOperationException("no delete")
                },
                nameOf = { it },
            )
            fail()
        } catch (e: IOException) {
            assertTrue(e.message!!.contains("b.json"))
        }
        assertEquals(listOf("doc:a.csv"), deleted)
    }

    @Test fun shownNameIsTheProvidersWhenKnown() {
        assertEquals("roll-4 (1).zip", SaveIo.shownName("roll-4 (1).zip", "roll-4.zip"))
        assertEquals("roll-4.zip", SaveIo.shownName(null, "roll-4.zip"))
        assertEquals("roll-4.zip", SaveIo.shownName("  ", "roll-4.zip"))
    }
}
