package com.socialgoogol.sgreader

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.socialgoogol.sgreader/open_file"
    private var initialFileMap: Map<String, String>? = null
    private var methodChannel: MethodChannel? = null

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
                    "deleteFilePermanently" -> {
                        val path = call.argument<String>("path")
                        val uriStr = call.argument<String>("uri")
                        var deleted = false

                        // 1. Delete via ContentResolver / DocumentsContract if URI was tracked
                        if (!uriStr.isNullOrBlank()) {
                            try {
                                val targetUri = Uri.parse(uriStr)
                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
                                    try {
                                        deleted = android.provider.DocumentsContract.deleteDocument(contentResolver, targetUri)
                                    } catch (eDoc: Exception) {
                                        val count = contentResolver.delete(targetUri, null, null)
                                        if (count > 0) deleted = true
                                    }
                                } else {
                                    val count = contentResolver.delete(targetUri, null, null)
                                    if (count > 0) deleted = true
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }

                        // 2. Delete physical file path
                        if (!path.isNullOrBlank()) {
                            try {
                                val f = File(path)
                                if (f.exists()) {
                                    if (f.delete()) deleted = true
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }

                        // 3. Delete via MediaStore if file is in shared storage
                        if (!path.isNullOrBlank() && path.startsWith("/storage")) {
                            try {
                                val mediaUri = android.provider.MediaStore.Files.getContentUri("external")
                                val count = contentResolver.delete(
                                    mediaUri,
                                    "${android.provider.MediaStore.MediaColumns.DATA}=?",
                                    arrayOf(path)
                                )
                                if (count > 0) deleted = true
                            } catch (e: Exception) {
                                // Ignore
                            }
                        }

                        result.success(deleted)
                    }
                    else -> result.notImplemented()
                }
            }
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

    private fun processIntent(intent: Intent?): Map<String, String>? {
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

        return try {
            val mimeType = try {
                contentResolver.getType(uri) ?: intent.type ?: ""
            } catch (e: Exception) {
                intent.type ?: ""
            }

            var fileName = "shared_document"
            try {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1) {
                            fileName = it.getString(nameIndex) ?: fileName
                        }
                    }
                }
            } catch (e: Exception) {
                // If contentResolver query is restricted, fallback to lastPathSegment
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

            // Ensure proper cache directory
            val cacheDir = File(cacheDir, "opened_docs").apply { mkdirs() }
            val destinationFile = File(cacheDir, fileName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destinationFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (destinationFile.exists() && destinationFile.length() > 0) {
                mapOf(
                    "path" to destinationFile.absolutePath,
                    "originalPath" to (if ("file" == uri.scheme) (uri.path ?: "") else ""),
                    "uri" to uri.toString(),
                    "name" to fileName,
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
}
