package io.github.wladikrin.grain.save

import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream

/** Provider-independent steps of a save, kept apart from Android for unit tests. */
object SaveIo {
    /**
     * Opens a document for writing with [open] (a content resolver's `openOutputStream`).
     * "wt" first; a provider that rejects it (FileNotFoundException "Unsupported mode", or an
     * IllegalArgumentException / UnsupportedOperationException) gets "w", and a file stream from
     * it is truncated, since "w" alone may keep old bytes past the new end. Our documents are new
     * and empty, so a stream that cannot be truncated (a pipe) is fine as it is.
     */
    fun openTruncating(open: (mode: String) -> OutputStream?): OutputStream {
        val wt = try {
            open("wt")
        } catch (e: FileNotFoundException) {
            null
        } catch (e: IllegalArgumentException) {
            null
        } catch (e: UnsupportedOperationException) {
            null
        }
        if (wt != null) return wt
        val w = open("w") ?: throw IOException("Couldn't open the file to write.")
        if (w is FileOutputStream) {
            try {
                w.channel.truncate(0)
            } catch (e: IOException) {
                // not a regular file: nothing to cut
            }
        }
        return w
    }

    /**
     * Creates and writes each of [items] in order. When one fails, every document this call
     * created, the failing one included, is removed with [delete] (best effort) and the error is
     * rethrown, so a failed save leaves nothing half-written behind. [create] returns null when
     * the provider made no document. Returns the documents in order.
     */
    fun <I, D> saveAll(
        items: List<I>,
        create: (I) -> D?,
        write: (I, D) -> Unit,
        delete: (D) -> Unit,
        nameOf: (I) -> String,
    ): List<D> {
        val made = mutableListOf<D>()
        try {
            for (item in items) {
                val doc = create(item)
                    ?: throw IOException("Couldn't create ${nameOf(item)} in that folder.")
                made += doc
                write(item, doc)
            }
            return made
        } catch (e: Exception) {
            for (doc in made.asReversed()) {
                try {
                    delete(doc)
                } catch (ignored: Exception) {
                    // the provider keeps it; the error below still reports the failure
                }
            }
            throw e
        }
    }

    /** The name a document got, or the one asked for when the provider does not tell. */
    fun shownName(queried: String?, requested: String): String =
        queried?.trim()?.takeIf { it.isNotEmpty() } ?: requested
}
