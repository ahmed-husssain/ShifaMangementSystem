package com.shifa.shifa_management

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaScannerConnection
import android.content.ContentValues
import android.provider.MediaStore
import android.os.Build
import android.os.Environment
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.shifa.shifa_management/media_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(path),
                            null
                        ) { _, uri ->
                            result.success(uri?.toString())
                        }
                    } else {
                        result.error("INVALID_PATH", "Path cannot be null", null)
                    }
                }
                "saveImageToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename") ?: "invoice_${System.currentTimeMillis()}.png"
                    
                    if (bytes != null) {
                        try {
                            val savedUri = saveImageToMediaStore(bytes, filename)
                            result.success(savedUri)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_BYTES", "Bytes cannot be null", null)
                    }
                }
                "saveFileToDownloads" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename") ?: "invoice_${System.currentTimeMillis()}.pdf"
                    val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                    
                    if (bytes != null) {
                        try {
                            val savedUri = saveFileToDownloads(bytes, filename, mimeType)
                            result.success(savedUri)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_BYTES", "Bytes cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun saveFileToDownloads(bytes: ByteArray, filename: String, mimeType: String): String {
        val resolver = applicationContext.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, filename)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/ShifaInvoices")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to create MediaStore Downloads entry")

            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw Exception("Failed to open output stream for Downloads URI")

            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            return uri.toString()
        } else {
            val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val subDir = File(downloadDir, "ShifaInvoices")
            if (!subDir.exists()) {
                subDir.mkdirs()
            }
            val targetFile = File(subDir, filename)
            targetFile.writeBytes(bytes)
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(targetFile.absolutePath),
                arrayOf(mimeType),
                null
            )
            return targetFile.absolutePath
        }
    }

    private fun saveImageToMediaStore(bytes: ByteArray, filename: String): String {
        val resolver = applicationContext.contentResolver
        val isJpeg = filename.endsWith(".jpg", ignoreCase = true) || filename.endsWith(".jpeg", ignoreCase = true)
        val mimeType = if (isJpeg) "image/jpeg" else "image/png"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val imageCollection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/ShifaInvoices")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }

            val uri = resolver.insert(imageCollection, contentValues)
                ?: throw Exception("Failed to create MediaStore entry")

            resolver.openOutputStream(uri)?.use { stream ->
                if (isJpeg) {
                    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    if (bitmap != null) {
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                    } else {
                        stream.write(bytes)
                    }
                } else {
                    stream.write(bytes)
                }
            } ?: throw Exception("Failed to open output stream for Image URI")

            contentValues.clear()
            contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            return uri.toString()
        } else {
            val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val subDir = File(picturesDir, "ShifaInvoices")
            if (!subDir.exists()) subDir.mkdirs()
            val targetFile = File(subDir, filename)
            if (isJpeg) {
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap != null) {
                    targetFile.outputStream().use { stream ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                    }
                } else {
                    targetFile.writeBytes(bytes)
                }
            } else {
                targetFile.writeBytes(bytes)
            }
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(targetFile.absolutePath),
                arrayOf(mimeType),
                null
            )
            return targetFile.absolutePath
        }
    }
}
