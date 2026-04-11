package com.digitalbaybd.pharmapos

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val dbChannelName = "pharmacy_pos/db_storage"
    private val dbFileName = "pharmacy.db"
    private val reqTree = 0x701

    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, dbChannelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "pickDocumentTree" -> {
                            pendingPickResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                            startActivityForResult(intent, reqTree)
                        }

                        "prepareDbFromTree" -> {
                            val treeUriStr = call.argument<String>("treeUri")
                                ?: throw IllegalArgumentException("Missing treeUri")
                            val runtimePath = call.argument<String>("runtimePath")
                                ?: throw IllegalArgumentException("Missing runtimePath")
                            val legacyPath = call.argument<String>("legacyPath")
                            val payload = prepareDbFromTree(treeUriStr, runtimePath, legacyPath)
                            result.success(payload)
                        }

                        "syncRuntimeToTree" -> {
                            val treeUriStr = call.argument<String>("treeUri")
                                ?: throw IllegalArgumentException("Missing treeUri")
                            val runtimePath = call.argument<String>("runtimePath")
                                ?: throw IllegalArgumentException("Missing runtimePath")
                            syncRuntimeToTree(treeUriStr, runtimePath)
                            result.success(true)
                        }

                        "readTreeDbBytes" -> {
                            val treeUriStr = call.argument<String>("treeUri")
                                ?: throw IllegalArgumentException("Missing treeUri")
                            val bytes = readTreeDbBytes(treeUriStr)
                            result.success(bytes)
                        }

                        "writeTreeDbBytes" -> {
                            val treeUriStr = call.argument<String>("treeUri")
                                ?: throw IllegalArgumentException("Missing treeUri")
                            val bytes = call.argument<ByteArray>("bytes")
                                ?: throw IllegalArgumentException("Missing bytes")
                            writeTreeDbBytes(treeUriStr, bytes)
                            result.success(true)
                        }

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("DB_STORAGE_ERROR", e.message, null)
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != reqTree) return
        val r = pendingPickResult
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            r?.success(null)
            return
        }
        val uri = data.data!!
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (_: SecurityException) {
            // Some providers may not support persistable; still return URI for session use.
        }
        r?.success(uri.toString())
    }

    private fun prepareDbFromTree(
        treeUriStr: String,
        runtimePath: String,
        legacyPath: String?
    ): Map<String, Any> {
        val treeUri = Uri.parse(treeUriStr)
        val tree = DocumentFile.fromTreeUri(this, treeUri)
            ?: throw IllegalStateException("Invalid folder URI")
        val runtime = File(runtimePath)
        runtime.parentFile?.mkdirs()

        val existing = tree.findFile(dbFileName)
        if (existing != null && existing.isFile) {
            contentResolver.openInputStream(existing.uri)?.use { input ->
                FileOutputStream(runtime, false).use { output -> input.copyTo(output) }
            } ?: throw IllegalStateException("Cannot read pharmacy.db from folder")
        } else {
            val legacy = legacyPath?.let { File(it) }
            if (legacy != null && legacy.exists()) {
                FileInputStream(legacy).use { input ->
                    FileOutputStream(runtime, false).use { output -> input.copyTo(output) }
                }
                syncRuntimeToTree(treeUriStr, runtimePath)
            } else {
                if (runtime.exists()) {
                    runtime.delete()
                }
            }
        }

        return mapOf("runtimePath" to runtimePath)
    }

    private fun syncRuntimeToTree(treeUriStr: String, runtimePath: String) {
        val treeUri = Uri.parse(treeUriStr)
        val tree = DocumentFile.fromTreeUri(this, treeUri) ?: return
        val runtime = File(runtimePath)
        if (!runtime.exists()) return

        var target = tree.findFile(dbFileName)
        if (target == null || !target.isFile) {
            target = tree.createFile("application/octet-stream", dbFileName)
        }
        val doc = target ?: return
        FileInputStream(runtime).use { input ->
            contentResolver.openOutputStream(doc.uri, "wt")?.use { output ->
                input.copyTo(output)
            }
        }
    }

    private fun readTreeDbBytes(treeUriStr: String): ByteArray {
        val treeUri = Uri.parse(treeUriStr)
        val tree = DocumentFile.fromTreeUri(this, treeUri) ?: return ByteArray(0)
        val doc = tree.findFile(dbFileName) ?: return ByteArray(0)
        if (!doc.isFile) return ByteArray(0)
        contentResolver.openInputStream(doc.uri)?.use { return it.readBytes() }
        return ByteArray(0)
    }

    private fun writeTreeDbBytes(treeUriStr: String, bytes: ByteArray) {
        val treeUri = Uri.parse(treeUriStr)
        val tree = DocumentFile.fromTreeUri(this, treeUri)
            ?: throw IllegalStateException("Invalid folder URI")
        var target = tree.findFile(dbFileName)
        if (target == null || !target.isFile) {
            target = tree.createFile("application/octet-stream", dbFileName)
        }
        val doc = target ?: throw IllegalStateException("Cannot create pharmacy.db in folder")
        contentResolver.openOutputStream(doc.uri, "wt")?.use { output ->
            output.write(bytes)
            output.flush()
        } ?: throw IllegalStateException("Cannot write pharmacy.db in folder")
    }
}
