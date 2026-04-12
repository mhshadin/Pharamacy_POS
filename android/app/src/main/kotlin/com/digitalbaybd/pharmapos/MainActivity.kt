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
                            val runtimeFile = File(runtimePath)
                            if (runtimeFile.exists()) {
                                var publicUri = getOrCreatePublicDbUri()
                                if (!tryWriteFileToUri(runtimeFile, publicUri)) {
                                    // Stale entry not writable — recreate and retry.
                                    contentResolver.delete(publicUri, null, null)
                                    publicUri = getOrCreatePublicDbUri()
                                    writeFileToUri(runtimeFile, publicUri)
                                }
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
        runtimeFile.parentFile?.mkdirs()

        // Look for an existing MediaStore entry without creating one yet.
        val existingUri = findPublicDbUri()
        val publicBytes: ByteArray = if (existingUri != null) safeReadUriBytes(existingUri) else ByteArray(0)

        if (publicBytes.isNotEmpty()) {
            // Restore the authoritative DB to the runtime working location.
            writeBytesToFile(publicBytes, runtimeFile)
        } else {
            // Entry is missing, stale, or empty (fresh install). Clean up any
            // orphan row so syncRuntimeToAuthoritative can write to a fresh one.
            if (existingUri != null) contentResolver.delete(existingUri, null, null)

            // Legacy migration: pre-MediaStore builds stored the DB at legacyPath.
            if (!legacyPath.isNullOrBlank()) {
                val legacyFile = File(legacyPath)
                if (legacyFile.exists()) writeFileToFile(legacyFile, runtimeFile)
            }
            // syncRuntimeToAuthoritative() will create and populate the public
            // entry once SQLite has finished initialising (see _initDatabase).
        }

        return mapOf(
            "runtimePath" to runtimePath,
            "publicRelativePath" to "$dbFolderName/$dbFileName"
        )
    }

    /** Queries MediaStore for the DB entry without creating one. Returns null if absent. */
    private fun findPublicDbUri(): Uri? {
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
        return null
    }

    /**
     * Returns an existing MediaStore entry or inserts a new one.
     * The new entry is left with IS_PENDING = 1 so the caller can open an
     * output stream immediately; the write helpers clear IS_PENDING after writing.
     */
    private fun getOrCreatePublicDbUri(): Uri {
        findPublicDbUri()?.let { return it }

        val contentUri = MediaStore.Downloads.EXTERNAL_CONTENT_URI
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
        return contentResolver.insert(contentUri, values)
            ?: throw IllegalStateException("Unable to create MediaStore DB entry")
    }

    /** Marks the MediaStore entry as finalised (IS_PENDING = 0). No-op below Android Q. */
    private fun clearPending(uri: Uri) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            contentResolver.update(uri, ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }, null, null)
        }
    }

    /**
     * Reads all bytes from a content URI.
     * Returns an empty array if the URI cannot be opened (stale entry, file deleted, etc.)
     * rather than throwing, so callers treat it as "no existing data".
     */
    private fun safeReadUriBytes(uri: Uri): ByteArray {
        return try {
            contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: ByteArray(0)
        } catch (_: Exception) {
            ByteArray(0)
        }
    }

    private fun readUriBytes(uri: Uri): ByteArray = safeReadUriBytes(uri)

    private fun writeBytesToUri(bytes: ByteArray, uri: Uri) {
        // Keep IS_PENDING=1 while the stream is open so Android lets us write,
        // then finalize to 0 on success.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            contentResolver.update(uri, ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 1)
            }, null, null)
        }
        contentResolver.openOutputStream(uri, "w")?.use { output ->
            output.write(bytes)
            output.flush()
            clearPending(uri)
            return
        }
        throw IllegalStateException("Unable to open MediaStore output stream")
    }

    private fun writeFileToUri(file: File, uri: Uri) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            contentResolver.update(uri, ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 1)
            }, null, null)
        }
        contentResolver.openOutputStream(uri, "w")?.use { output ->
            FileInputStream(file).use { input -> input.copyTo(output) }
            output.flush()
            clearPending(uri)
            return
        }
        throw IllegalStateException("Unable to open MediaStore output stream")
    }

    /** Returns true on success, false if the output stream cannot be opened (stale entry). */
    private fun tryWriteFileToUri(file: File, uri: Uri): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentResolver.update(uri, ContentValues().apply {
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }, null, null)
            }
            contentResolver.openOutputStream(uri, "w")?.use { output ->
                FileInputStream(file).use { input -> input.copyTo(output) }
                output.flush()
                clearPending(uri)
            } ?: return false
            true
        } catch (_: Exception) {
            false
        }
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
