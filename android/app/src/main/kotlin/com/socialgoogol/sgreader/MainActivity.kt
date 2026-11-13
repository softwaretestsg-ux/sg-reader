package com.socialgoogol.sgreader

import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.socialgoogol.sgreader/open_file"
    private val REQUEST_CODE_PICK_DOCUMENT = 1010
    private var initialFileMap: Map<String, Any>? = null
    private var methodChannel: MethodChannel? = null
    private var pendingPickResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialFileMap = processIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFile" -> {
                        result.success(initialFileMap)
                        initialFileMap = null // Consume once
                    }
                    "hasStoragePermission" -> {
                        result.success(isAllFilesAccessGranted())
                    }
                    "requestStoragePermission" -> {
                        requestAllFilesAccess()
                        result.success(true)
                    }
                    "pickDocument" -> {
                        if (pendingPickResult != null) {
                            try {
                                pendingPickResult?.error("ALREADY_ACTIVE", "A document picker is already active", null)
                            } catch (_: Exception) {}
                        }
                        pendingPickResult = result
                        launchNativeDocumentPicker()
                    }
                    "deleteFilePermanently" -> {
                        val path = call.argument<String>("path")
                        val originalPath = call.argument<String>("originalPath")
                        val uriStr = call.argument<String>("uri")
                        val name = call.argument<String>("name")
                        var wasDeleted = false

                        // 1. Delete via ContentResolver / DocumentsContract if URI was tracked
                        if (!uriStr.isNullOrBlank()) {
                            try {
                                val targetUri = Uri.parse(uriStr)
                                try {
                                    val deleted = DocumentsContract.deleteDocument(contentResolver, targetUri)
                                    if (deleted) wasDeleted = true
                                } catch (eDoc: Exception) {
                                    val count = contentResolver.delete(targetUri, null, null)
                                    if (count > 0) wasDeleted = true
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }

                        // 2. Delete physical file via originalPath
                        if (!originalPath.isNullOrBlank()) {
                            try {
                                val origFile = File(originalPath)
                                if (origFile.exists()) {
                                    if (origFile.delete()) wasDeleted = true
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }

                        // 3. Fallback search & delete by filename in standard device storage directories
                        if (!name.isNullOrBlank()) {
                            try {
                                val publicDirs = listOf(
                                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
                                    Environment.getExternalStorageDirectory()
                                )
                                for (dir in publicDirs) {
                                    if (dir != null && dir.exists()) {
                                        val candidate = File(dir, name)
                                        if (candidate.exists()) {
                                            if (candidate.delete()) wasDeleted = true
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }

                        // 4. Delete via MediaStore if file is indexed
                        val candidatePath = if (!originalPath.isNullOrBlank()) originalPath else path
                        if (!candidatePath.isNullOrBlank() && candidatePath.startsWith("/storage")) {
                            try {
                                val mediaUri = MediaStore.Files.getContentUri("external")
                                val count = contentResolver.delete(
                                    mediaUri,
                                    "${MediaStore.MediaColumns.DATA}=?",
                                    arrayOf(candidatePath)
                                )
                                if (count > 0) wasDeleted = true
                            } catch (e: Exception) {
                                // Ignore
                            }
                        }

                        // 5. Delete internal sandbox cache copy
                        if (!path.isNullOrBlank()) {
                            try {
                                val cacheFile = File(path)
                                if (cacheFile.exists()) {
                                    if (cacheFile.delete()) wasDeleted = true
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }

                        result.success(wasDeleted)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun isAllFilesAccessGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                startActivity(intent)
            }
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    android.Manifest.permission.WRITE_EXTERNAL_STORAGE,
                    android.Manifest.permission.READ_EXTERNAL_STORAGE
                ),
                1001
            )
        }
    }

    private fun launchNativeDocumentPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/pdf",
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                    "application/msword",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    "application/vnd.ms-excel",
                    "text/csv",
                    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                    "application/vnd.ms-powerpoint"
                )
            )
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        }
        try {
            startActivityForResult(intent, REQUEST_CODE_PICK_DOCUMENT)
        } catch (e: Exception) {
            pendingPickResult?.error("PICKER_FAILED", "Failed to launch system document picker: ${e.message}", null)
            pendingPickResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_DOCUMENT) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                // Take persistable permission for persistent access and deletion
                try {
                    val takeFlags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    contentResolver.takePersistableUriPermission(uri, takeFlags)
                } catch (e: Exception) {
                    // Ignore if provider doesn't support persistable flags
                }

                val docMap = processDocumentUri(uri)
                pendingPickResult?.success(docMap)
            } else {
                pendingPickResult?.success(null)
            }
            pendingPickResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val fileMap = processIntent(intent)
        if (fileMap != null) {
            methodChannel?.invokeMethod("onFileOpened", fileMap)
        }
    }

    private fun processIntent(intent: Intent?): Map<String, Any>? {
        if (intent == null) return null
        val action = intent.action
        if (Intent.ACTION_VIEW != action && Intent.ACTION_SEND != action) {
            return null
        }

        val uri: Uri? = if (Intent.ACTION_SEND == action) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        } else {
            intent.data
        }

        if (uri == null) return null
        return processDocumentUri(uri)
    }

    private fun processDocumentUri(uri: Uri): Map<String, Any>? {
        return try {
            val mimeType = try {
                contentResolver.getType(uri) ?: ""
            } catch (e: Exception) { "" }

            var fileName = "shared_document"
            var fileSize: Long = 0
            try {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1) {
                            fileName = cursor.getString(nameIndex) ?: fileName
                        }
                        val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (sizeIndex != -1) {
                            fileSize = cursor.getLong(sizeIndex)
                        }
                    }
                }
            } catch (e: Exception) {
                // Ignore
            }

            if (fileName == "shared_document" || !fileName.contains(".")) {
                val lastSegment = uri.lastPathSegment
                if (!lastSegment.isNullOrBlank() && lastSegment.contains(".")) {
                    fileName = lastSegment.substringAfterLast('/')
                }
            }

            // Infer extension from MIME type if still missing
            if (!fileName.contains(".")) {
                val inferredExt = when {
                    mimeType.contains("pdf", ignoreCase = true) -> ".pdf"
                    mimeType.contains("wordprocessingml", ignoreCase = true) || mimeType.contains("msword", ignoreCase = true) -> ".docx"
                    mimeType.contains("spreadsheetml", ignoreCase = true) || mimeType.contains("ms-excel", ignoreCase = true) -> ".xlsx"
                    mimeType.contains("csv", ignoreCase = true) -> ".csv"
                    mimeType.contains("presentationml", ignoreCase = true) || mimeType.contains("ms-powerpoint", ignoreCase = true) -> ".pptx"
                    else -> ""
                }
                if (inferredExt.isNotEmpty()) {
                    fileName = "$fileName$inferredExt"
                }
            }

            // Resolve real storage path
            var originalPath = getPathFromUri(this, uri) ?: ""

            // Fallback search in public Downloads/Documents if path is empty
            if (originalPath.isEmpty()) {
                val downloadCandidate = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), fileName)
                if (downloadCandidate.exists()) {
                    originalPath = downloadCandidate.absolutePath
                } else {
                    val docCandidate = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS), fileName)
                    if (docCandidate.exists()) {
                        originalPath = docCandidate.absolutePath
                    }
                }
            }

            // Ensure proper cache directory
            val cacheDir = File(cacheDir, "opened_docs").apply { mkdirs() }
            val destinationFile = File(cacheDir, fileName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destinationFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (fileSize == 0L && destinationFile.exists()) {
                fileSize = destinationFile.length()
            }

            if (destinationFile.exists() && destinationFile.length() > 0) {
                mapOf(
                    "path" to destinationFile.absolutePath,
                    "originalPath" to originalPath,
                    "uri" to uri.toString(),
                    "name" to fileName,
                    "sizeInBytes" to fileSize,
                    "mimeType" to mimeType
                )
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun getPathFromUri(context: Context, uri: Uri): String? {
        if ("file".equals(uri.scheme, ignoreCase = true)) {
            return uri.path
        }

        if (DocumentsContract.isDocumentUri(context, uri)) {
            val docId = DocumentsContract.getDocumentId(uri)
            if ("com.android.externalstorage.documents" == uri.authority) {
                val split = docId.split(":")
                val type = split[0]
                return if ("primary".equals(type, ignoreCase = true)) {
                    "${Environment.getExternalStorageDirectory().absolutePath}/${split.getOrNull(1) ?: ""}"
                } else {
                    "/storage/$type/${split.getOrNull(1) ?: ""}"
                }
            } else if ("com.android.providers.downloads.documents" == uri.authority) {
                if (docId.startsWith("raw:")) {
                    return docId.substring(4)
                }
                try {
                    val contentUri = ContentUris.withAppendedId(
                        Uri.parse("content://downloads/public_downloads"),
                        docId.toLong()
                    )
                    val path = getDataColumn(context, contentUri, null, null)
                    if (!path.isNullOrBlank()) return path
                } catch (e: Exception) {
                    // Ignore
                }
            } else if ("com.android.providers.media.documents" == uri.authority) {
                val split = docId.split(":")
                val id = split.getOrNull(1) ?: docId
                val contentUri = MediaStore.Files.getContentUri("external")
                val path = getDataColumn(context, contentUri, "_id=?", arrayOf(id))
                if (!path.isNullOrBlank()) return path
            }
        }

        if ("content".equals(uri.scheme, ignoreCase = true)) {
            val path = getDataColumn(context, uri, null, null)
            if (!path.isNullOrBlank()) return path
        }

        return null
    }

    private fun getDataColumn(context: Context, uri: Uri, selection: String?, selectionArgs: Array<String>?): String? {
        return try {
            val column = MediaStore.MediaColumns.DATA
            val projection = arrayOf(column)
            context.contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val columnIndex = cursor.getColumnIndex(column)
                    if (columnIndex != -1) {
                        return cursor.getString(columnIndex)
                    }
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }
}
