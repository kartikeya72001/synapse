package com.synapse.synapse

import android.content.ContentUris
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.synapse.synapse/quicksettings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAction" -> {
                    val action = intent?.getStringExtra("action")
                    intent?.removeExtra("action")
                    result.success(action)
                }
                "listScreenshots" -> {
                    try {
                        val paths = listScreenshotsViaMediaStore()
                        if (paths.isEmpty()) {
                            // Fallback to filesystem scan
                            result.success(listScreenshotsFromFilesystem())
                        } else {
                            result.success(paths)
                        }
                    } catch (e: Exception) {
                        result.success(listScreenshotsFromFilesystem())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun listScreenshotsViaMediaStore(): List<String> {
        val paths = mutableListOf<String>()

        val collection: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DATA,
            MediaStore.Images.Media.DATE_MODIFIED,
            MediaStore.Images.Media.RELATIVE_PATH,
            MediaStore.Images.Media.DISPLAY_NAME,
        )

        // Match common screenshot folder patterns across OEMs
        val selection = buildString {
            append("(")
            append("${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(")")
        }

        val selectionArgs = arrayOf(
            "%Screenshots%",
            "%screenshots%",
            "%Screen capture%",
            "%screen capture%",
            "%DCIM/Screenshots%",
            "%Pictures/Screenshots%",
            "%Screenshot%",
            "%ScreenCapture%",
        )

        val sortOrder = "${MediaStore.Images.Media.DATE_MODIFIED} DESC"

        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                collection,
                projection,
                selection,
                selectionArgs,
                sortOrder,
            )

            cursor?.let {
                val dataColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
                while (it.moveToNext()) {
                    val path = it.getString(dataColumn)
                    if (path != null) {
                        val file = File(path)
                        if (file.exists() && file.length() > 0) {
                            paths.add(path)
                        }
                    }
                }
            }
        } finally {
            cursor?.close()
        }

        return paths
    }

    private fun listScreenshotsFromFilesystem(): List<String> {
        val paths = mutableListOf<String>()
        val dirs = mutableListOf<File>()

        val extStorage = Environment.getExternalStorageDirectory()
        val pictures = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val dcim = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)

        val candidates = listOf(
            File(pictures, "Screenshots"),
            File(pictures, "screenshots"),
            File(dcim, "Screenshots"),
            File(dcim, "screenshots"),
            File(dcim, "Screen capture"),
            File(dcim, "ScreenCapture"),
            File(extStorage, "Screenshots"),
            File(extStorage, "screenshots"),
            File(extStorage, "Pictures"),
            File(extStorage, "DCIM"),
        )

        for (dir in candidates) {
            if (dir.exists() && dir.isDirectory) {
                dirs.add(dir)
            }
        }

        val imageExtensions = setOf("png", "jpg", "jpeg", "webp")
        for (dir in dirs) {
            val files = dir.listFiles { file ->
                file.isFile && file.extension.lowercase() in imageExtensions && file.length() > 0
            }
            files?.forEach { paths.add(it.absolutePath) }
        }

        // Sort newest first
        paths.sortByDescending { File(it).lastModified() }
        return paths.distinct()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.getStringExtra("action")
        if (action == "save_latest_screenshot") {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onQuickCapture", null)
            }
        }
    }
}
