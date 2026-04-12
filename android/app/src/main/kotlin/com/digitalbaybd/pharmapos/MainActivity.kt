package com.digitalbaybd.pharmapos

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val dbChannelName = "pharmacy_pos/db_storage"
    private val dbFolderName = "Pharmacy POS"
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

                        "prepareDatabasePath" -> {
                            val runtimePath = call.argument<String>("runtimePath")
                                ?: throw IllegalArgumentException("Missing runtimePath")
                            val legacyPath = call.argument<String>("legacyPath")
                            val payload = prepareDatabasePath(runtimePath, legacyPath)
                            result.success(payload)
                        }

                        "syncRuntimeToPublicDb" -> {
                            val runtimePath = call.argument<String>("runtimePath")
                                ?: throw IllegalArgumentException("Missing runtimePath")
                            val publicUri = getOrCreatePublicDbUri()
                            val runtimeFile = File(runtimePath)
                            if (runtimeFile.exists()) {
                                writeFileToUri(runtimeFile, publicUri)
                            }
                            result.success(true)
                        }

                        "readPublicDbBytes" -> {
                            val publicUri = getOrCreatePublicDbUri()
                            val bytes = readUriBytes(publicUri)
                            result.success(bytes)
                        }

                        "writePublicDbBytes" -> {
                            val bytes = call.argument<ByteArray>("bytes")
                                ?: throw IllegalArgumentException("Missing bytes")
                            val publicUri = getOrCreatePublicDbUri()
                            writeBytesToUri(bytes, publicUri)
                            result.success(true)
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
        }
        r?.success(uri.toString())
    }

    // --- MediaStore: Downloads/Pharmacy POS/pharmacy.db (default Android) ---

    private fun prepareDatabasePath(runtimePath: String, legacyPath: String?): Map<String, Any> {
        val runtimeFile = File(runtimePath)
        val runtimeParent = runtimeFile.parentFile
        if (runtimeParent != null && !runtimeParent.exists()) {
            runtimeParent.mkdirs()
        }

        var publicUri = getOrCreatePublicDbUri()
        val publicBytes: ByteArray = try {
            readUriBytes(publicUri)
        } catch (_: FileNotFoundException) {
            // Stale MediaStore row — the file was deleted externally. Delete the
            // orphan entry and create a fresh one so the next open succeeds.
            contentResolver.delete(publicUri, null, null)
            publicUri = getOrCreatePublicDbUri()
            ByteArray(0)
        }
        val publicExists = publicBytes.isNotEmpty()

        if (publicExists) {
            writeBytesToFile(publicBytes, runtimeFile)
        } else {
            val migratedFromLegacy = if (!legacyPath.isNullOrBlank()) {
                val legacyFile = File(legacyPath)
                if (legacyFile.exists()) {
                    writeFileToUri(legacyFile, publicUri)
                    writeFileToFile(legacyFile, runtimeFile)
                    true
                } else {
                    false
                }
            } else {
                false
            }

            if (!migratedFromLegacy && runtimeFile.exists()) {
                writeFileToUri(runtimeFile, publicUri)
            }
        }

        return mapOf(
            "runtimePath" to runtimePath,
            "publicRelativePath" to "$dbFolderName/$dbFileName"
        )
    }

    private fun getOrCreatePublicDbUri(): Uri {
        val contentUri = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.Downloads._ID)
        val selection =
            "${MediaStore.Downloads.RELATIVE_PATH} = ? AND ${MediaStore.Downloads.DISPLAY_NAME} = ?"
        val selectionArgs = arrayOf(
            "${Environment.DIRECTORY_DOWNLOADS}/$dbFolderName/",
            dbFileName
        )

        contentResolver.query(contentUri, projection, selection, selectionArgs, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID))
                return Uri.withAppendedPath(contentUri, id.toString())
            }
        }

        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, dbFileName)
            put(MediaStore.Downloads.MIME_TYPE, "application/octet-stream")
            put(
                MediaStore.Downloads.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}/$dbFolderName/"
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
        }

        val uri = contentResolver.insert(contentUri, values)
            ?: throw IllegalStateException("Unable to create MediaStore DB entry")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val readyValues = ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }
            contentResolver.update(uri, readyValues, null, null)
        }

        return uri
    }

    private fun readUriBytes(uri: Uri): ByteArray {
        // openInputStream can throw FileNotFoundException when a MediaStore row
        // exists but the backing file has been deleted externally.
        val stream = contentResolver.openInputStream(uri) ?: return ByteArray(0)
        return stream.use { it.readBytes() }
    }

    private fun writeBytesToUri(bytes: ByteArray, uri: Uri) {
        contentResolver.openOutputStream(uri, "wt")?.use { output ->
            output.write(bytes)
            output.flush()
            return
        }
        throw IllegalStateException("Unable to open MediaStore output stream")
    }

    private fun writeFileToUri(file: File, uri: Uri) {
        contentResolver.openOutputStream(uri, "wt")?.use { output ->
            FileInputStream(file).use { input ->
                input.copyTo(output)
            }
            output.flush()
            return
        }
        throw IllegalStateException("Unable to open MediaStore output stream")
    }

    private fun writeBytesToFile(bytes: ByteArray, file: File) {
        FileOutputStream(file, false).use { output ->
            output.write(bytes)
            output.flush()
        }
    }

    private fun writeFileToFile(source: File, target: File) {
        FileInputStream(source).use { input ->
            FileOutputStream(target, false).use { output ->
                input.copyTo(output)
                output.flush()
            }
        }
    }

    // --- SAF: optional custom folder ---

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
