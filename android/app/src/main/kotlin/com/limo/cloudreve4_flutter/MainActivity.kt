package com.limo.cloudreve4_flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.FileInputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val contentReaderChannel = "cloudreve/content_reader"
    private val pickFilesRequestCode = 46110
    private var pendingPickFilesResult: MethodChannel.Result? = null

    private lateinit var channel: MethodChannel
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            contentReaderChannel
        )

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFiles" -> {
                    if (pendingPickFilesResult != null) {
                        result.error("PICKER_BUSY", "Another file picker request is still active.", null)
                        return@setMethodCallHandler
                    }

                    val type = call.argument<String>("type") ?: "any"
                    val allowMultiple = call.argument<Boolean>("allowMultiple") ?: true
                    pendingPickFilesResult = result

                    try {
                        launchFilePicker(type, allowMultiple)
                    } catch (e: Exception) {
                        pendingPickFilesResult = null
                        result.error("PICKER_FAILED", e.message ?: e.javaClass.simpleName, null)
                    }
                }

                "persistReadPermission" -> {
                    val uriText = call.argument<String>("uri")
                    if (uriText.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    result.success(persistReadPermission(uriText))
                }

                "readChunk" -> {
                    executor.execute {
                        try {
                            val uriText = call.argument<String>("uri")
                                ?: throw IllegalArgumentException("uri is required")
                            val offset = call.argument<Number>("offset")?.toLong()
                                ?: throw IllegalArgumentException("offset is required")
                            val length = call.argument<Number>("length")?.toInt()
                                ?: throw IllegalArgumentException("length is required")

                            val bytes = readChunk(uriText, offset, length)
                            mainHandler.post { result.success(bytes) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error(
                                    "CONTENT_READ_FAILED",
                                    e.message ?: e.javaClass.simpleName,
                                    null
                                )
                            }
                        }
                    }
                }

                "uploadChunkToUrl" -> {
                    executor.execute {
                        try {
                            val transferId = call.argument<String>("transferId")
                                ?: throw IllegalArgumentException("transferId is required")
                            val uriText = call.argument<String>("uri")
                                ?: throw IllegalArgumentException("uri is required")
                            val uploadUrl = call.argument<String>("uploadUrl")
                                ?: throw IllegalArgumentException("uploadUrl is required")
                            val method = call.argument<String>("method") ?: "PUT"
                            val offset = call.argument<Number>("offset")?.toLong()
                                ?: throw IllegalArgumentException("offset is required")
                            val length = call.argument<Number>("length")?.toInt()
                                ?: throw IllegalArgumentException("length is required")
                            val headers = call.argument<Map<String, String>>("headers")
                                ?: emptyMap()

                            val response = uploadChunkToUrl(
                                transferId = transferId,
                                uriText = uriText,
                                uploadUrl = uploadUrl,
                                method = method,
                                offset = offset,
                                length = length,
                                headers = headers,
                            )

                            mainHandler.post { result.success(response) }
                        } catch (e: NativeHttpException) {
                            mainHandler.post {
                                result.error(
                                    "HTTP_${e.statusCode}",
                                    e.body,
                                    mapOf(
                                        "statusCode" to e.statusCode,
                                        "body" to e.body,
                                        "headers" to e.headers
                                    )
                                )
                            }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error(
                                    "NATIVE_UPLOAD_FAILED",
                                    e.message ?: e.javaClass.simpleName,
                                    null
                                )
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun launchFilePicker(type: String, allowMultiple: Boolean) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            this.type = mimeTypeForPicker(type)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }

        startActivityForResult(intent, pickFilesRequestCode)
    }

    private fun mimeTypeForPicker(type: String): String {
        return when (type.lowercase()) {
            "image" -> "image/*"
            "video" -> "video/*"
            "audio" -> "audio/*"
            else -> "*/*"
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == pickFilesRequestCode) {
            val result = pendingPickFilesResult
            pendingPickFilesResult = null

            if (result == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }

            if (resultCode != Activity.RESULT_OK || data == null) {
                result.success(emptyList<Map<String, Any?>>())
                return
            }

            try {
                val items = collectPickedFiles(data)
                result.success(items)
            } catch (e: Exception) {
                result.error("PICKER_RESULT_FAILED", e.message ?: e.javaClass.simpleName, null)
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun collectPickedFiles(data: Intent): List<Map<String, Any?>> {
        val result = ArrayList<Map<String, Any?>>()

        val clipData = data.clipData
        if (clipData != null && clipData.itemCount > 0) {
            for (i in 0 until clipData.itemCount) {
                val uri = clipData.getItemAt(i).uri ?: continue
                persistReadPermission(uri.toString())
                result.add(fileInfoMap(uri))
            }
            return result
        }

        data.data?.let { uri ->
            persistReadPermission(uri.toString())
            result.add(fileInfoMap(uri))
        }

        return result
    }

    private fun fileInfoMap(uri: Uri): Map<String, Any?> {
        val displayNameAndSize = queryDisplayNameAndSize(uri)
        val name = displayNameAndSize.first ?: uri.lastPathSegment ?: "unknown"
        val size = displayNameAndSize.second ?: querySizeFromFileDescriptor(uri) ?: 0L
        val mimeType = contentResolver.getType(uri)

        return mapOf(
            "uri" to uri.toString(),
            "name" to name,
            "size" to size,
            "mimeType" to mimeType
        )
    }

    private fun queryDisplayNameAndSize(uri: Uri): Pair<String?, Long?> {
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return Pair(null, null)

                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)

                val name = if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                    cursor.getString(nameIndex)
                } else {
                    null
                }

                val size = if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                    cursor.getLong(sizeIndex)
                } else {
                    null
                }

                Pair(name, size)
            } ?: Pair(null, null)
        } catch (_: Exception) {
            Pair(null, null)
        }
    }

    private fun querySizeFromFileDescriptor(uri: Uri): Long? {
        return try {
            contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                val statSize = pfd.statSize
                if (statSize >= 0) statSize else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun persistReadPermission(uriText: String): Boolean {
        return try {
            val uri = Uri.parse(uriText)
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            contentResolver.takePersistableUriPermission(uri, flags)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun readChunk(uriText: String, offset: Long, length: Int): ByteArray {
        require(offset >= 0) { "offset must be >= 0" }
        require(length >= 0) { "length must be >= 0" }
        if (length == 0) return ByteArray(0)

        val uri = Uri.parse(uriText)

        try {
            contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                FileInputStream(pfd.fileDescriptor).use { fis ->
                    val channel = fis.channel
                    channel.position(offset)
                    return readExact(fis, length)
                }
            }
        } catch (_: Exception) {
        }

        contentResolver.openInputStream(uri)?.use { input ->
            skipFully(input, offset)
            return readExact(input, length)
        }

        throw IllegalStateException("Cannot open input stream: $uriText")
    }

    private fun uploadChunkToUrl(
        transferId: String,
        uriText: String,
        uploadUrl: String,
        method: String,
        offset: Long,
        length: Int,
        headers: Map<String, String>,
    ): Map<String, Any?> {
        require(offset >= 0) { "offset must be >= 0" }
        require(length >= 0) { "length must be >= 0" }

        val connection = URL(uploadUrl).openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.doOutput = true
        connection.instanceFollowRedirects = false
        connection.connectTimeout = 120_000
        connection.readTimeout = 600_000

        headers.forEach { (key, value) ->
            connection.setRequestProperty(key, value)
        }

        connection.setFixedLengthStreamingMode(length)

        val uri = Uri.parse(uriText)

        try {
            connection.connect()

            connection.outputStream.use { output ->
                try {
                    contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                        FileInputStream(pfd.fileDescriptor).use { fis ->
                            fis.channel.position(offset)
                            copyExactToOutput(transferId, fis, output, length)
                            return@use
                        }
                    }
                } catch (_: Exception) {
                    contentResolver.openInputStream(uri)?.use { input ->
                        skipFully(input, offset)
                        copyExactToOutput(transferId, input, output, length)
                    } ?: throw IllegalStateException("Cannot open input stream: $uriText")
                }
            }

            val status = connection.responseCode
            val body = readResponseBody(connection, status)
            val responseHeaders = connection.headerFields
                ?.filterKeys { it != null }
                ?.mapKeys { it.key ?: "" }
                ?.mapValues { it.value?.joinToString(",") ?: "" }
                ?: emptyMap()

            if (status !in 200..299) {
                throw NativeHttpException(status, body, responseHeaders)
            }

            return mapOf(
                "statusCode" to status,
                "body" to body,
                "headers" to responseHeaders
            )
        } finally {
            connection.disconnect()
        }
    }

    private fun copyExactToOutput(
        transferId: String,
        input: InputStream,
        output: java.io.OutputStream,
        length: Int
    ) {
        val buffer = ByteArray(256 * 1024)
        var remaining = length
        var sent = 0
        var lastProgressAt = 0L

        while (remaining > 0) {
            val read = input.read(buffer, 0, minOf(buffer.size, remaining))
            if (read <= 0) break

            output.write(buffer, 0, read)
            sent += read
            remaining -= read

            val now = System.currentTimeMillis()
            if (sent == length || now - lastProgressAt >= 500) {
                lastProgressAt = now
                postUploadProgress(transferId, sent, length)
            }
        }

        output.flush()

        if (sent != length) {
            throw IllegalStateException("Unexpected EOF while uploading chunk: sent=$sent expected=$length")
        }

        postUploadProgress(transferId, sent, length)
    }

    private fun postUploadProgress(transferId: String, sent: Int, total: Int) {
        mainHandler.post {
            channel.invokeMethod(
                "uploadProgress",
                mapOf(
                    "transferId" to transferId,
                    "sent" to sent,
                    "total" to total
                )
            )
        }
    }

    private fun readResponseBody(connection: HttpURLConnection, status: Int): String {
        return try {
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            stream?.bufferedReader()?.use { it.readText() } ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    private fun readExact(input: InputStream, length: Int): ByteArray {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        val out = ByteArrayOutputStream(length)
        var remaining = length

        while (remaining > 0) {
            val read = input.read(buffer, 0, minOf(buffer.size, remaining))
            if (read <= 0) break
            out.write(buffer, 0, read)
            remaining -= read
        }

        return out.toByteArray()
    }

    private fun skipFully(input: InputStream, bytesToSkip: Long) {
        var remaining = bytesToSkip
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)

        while (remaining > 0) {
            val skipped = input.skip(remaining)
            if (skipped > 0) {
                remaining -= skipped
                continue
            }

            val read = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
            if (read <= 0) {
                throw IllegalStateException("Cannot skip to requested offset")
            }
            remaining -= read.toLong()
        }
    }

    class NativeHttpException(
        val statusCode: Int,
        val body: String,
        val headers: Map<String, String>
    ) : Exception("HTTP $statusCode: $body")
}
