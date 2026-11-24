package io.github.wladikrin.grain.save

/** Pure helpers for naming the files handed to the document provider. */
object SaveNames {
    private val mimes = mapOf(
        "csv" to "text/csv",
        "json" to "application/json",
        "zip" to "application/zip",
        "jpg" to "image/jpeg",
        "jpeg" to "image/jpeg",
        "txt" to "text/plain",
    )

    fun mimeFor(name: String): String {
        val dot = name.lastIndexOf('.')
        val ext = if (dot < 0) "" else name.substring(dot + 1).lowercase()
        return mimes[ext] ?: "application/octet-stream"
    }

    /** A display name safe to hand to a provider: no path parts, never empty. */
    fun clean(name: String): String {
        val base = name.substringAfterLast('/').substringAfterLast('\\').trim()
        return base.ifEmpty { "file" }
    }
}
