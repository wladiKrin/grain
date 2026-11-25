package io.github.wladikrin.grain.save

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.concurrent.Executors

/**
 * `grain/save` method channel: `save {files: [{path, name, mime?}]}` -> {status: "saved", names}
 * or {status: "cancelled"}; `error("save", message)` on failure. One file opens the system
 * "create document" picker; several open a folder picker and each is created in it. The storage
 * access framework needs no permission, and no URI grant is kept. Bytes are copied on a worker
 * thread. A name that is taken is renamed by the provider, never overwritten; `names` are the
 * names the documents got. A failed save removes the documents it created. Grain saves one file
 * (a roll as one zip), since Android 11+ will not let a folder pick choose the Downloads root.
 */
class SavePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {
    private class Item(val path: String, val name: String, val mime: String)
    private class Pending(val items: List<Item>, val result: MethodChannel.Result, val tree: Boolean)

    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: Pending? = null
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "grain/save").also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        worker.shutdown()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detach(keepPending = true)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detach(keepPending = false)

    private fun detach(keepPending: Boolean) {
        binding?.removeActivityResultListener(this)
        binding = null
        if (!keepPending) {
            pending?.result?.error("save", "The app was closed before saving.", null)
            pending = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "save") return result.notImplemented()
        val activity = binding?.activity
        if (activity == null) return result.error("save", "No screen to show the picker.", null)
        if (pending != null) return result.error("save", "Already saving.", null)
        val items = (call.argument<List<Map<String, Any?>>>("files") ?: emptyList()).map {
            val name = SaveNames.clean(it["name"] as String)
            Item(it["path"] as String, name, (it["mime"] as? String) ?: SaveNames.mimeFor(name))
        }
        if (items.isEmpty()) return result.error("save", "Nothing to save.", null)
        val tree = items.size > 1
        val intent = if (tree) {
            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        } else {
            Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                .setType(items[0].mime).putExtra(Intent.EXTRA_TITLE, items[0].name)
        }
        pending = Pending(items, result, tree)
        try {
            activity.startActivityForResult(intent, REQUEST)
        } catch (e: Exception) {
            pending = null
            result.error("save", e.message ?: "No file picker available.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val p = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            p.result.success(mapOf("status" to "cancelled"))
            return true
        }
        val resolver = binding?.activity?.contentResolver
        if (resolver == null) {
            p.result.error("save", "The app was closed before saving.", null)
            return true
        }
        worker.execute {
            try {
                val parent = if (p.tree) {
                    DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
                } else {
                    null
                }
                val docs = SaveIo.saveAll(
                    p.items,
                    // One file: the picker already made the document, so a failed write removes it too.
                    create = { item ->
                        if (parent == null) uri else DocumentsContract.createDocument(resolver, parent, item.mime, item.name)
                    },
                    write = { item, doc -> copy(resolver, item.path, doc) },
                    delete = { DocumentsContract.deleteDocument(resolver, it) },
                    nameOf = { it.name },
                )
                val names = docs.mapIndexed { i, doc ->
                    SaveIo.shownName(displayName(resolver, doc), p.items[i].name)
                }
                main.post { p.result.success(mapOf("status" to "saved", "names" to names)) }
            } catch (e: Exception) {
                main.post { p.result.error("save", e.message ?: e.javaClass.simpleName, null) }
            }
        }
        return true
    }

    private fun copy(resolver: ContentResolver, path: String, to: Uri) {
        SaveIo.openTruncating { mode -> resolver.openOutputStream(to, mode) }
            .use { o -> File(path).inputStream().use { it.copyTo(o) } }
    }

    /** The name the provider gave [doc]: the user may rename it in the picker, a taken name gets " (1)". */
    private fun displayName(resolver: ContentResolver, doc: Uri): String? = try {
        resolver.query(doc, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) c.getString(0) else null
        }
    } catch (e: Exception) {
        null
    }

    private companion object {
        const val REQUEST = 4271
    }
}
