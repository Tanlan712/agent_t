package io.github.tanlan712.agent_t

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 檔案的儲存、分享與開啟（channel `agent_t/files`）：今日小結圖片與本機資料備份用。
 * 只處理使用者按下按鈕時交給它的資料，不連網、不讀其他檔案；分享的暫存檔放在快取 shared/。
 */
class FileBridge(private val activity: Activity) {
    private var pending: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "share" -> {
                val name = safeName(call.argument<String>("name"))
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes")
                if (name == null || bytes == null) {
                    result.error("bad_args", "missing file", null)
                    return
                }
                try {
                    val dir = File(activity.cacheDir, "shared").apply { mkdirs() }
                    dir.listFiles()?.forEach { it.delete() }
                    val file = File(dir, name)
                    file.writeBytes(bytes)
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = mime
                        putExtra(Intent.EXTRA_STREAM, uri)
                        call.argument<String>("text")?.let { putExtra(Intent.EXTRA_TEXT, it) }
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    activity.startActivity(Intent.createChooser(send, null))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("share_failed", e.javaClass.simpleName, null)
                }
            }
            "save" -> {
                val name = safeName(call.argument<String>("name"))
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes")
                if (name == null || bytes == null || pending != null) {
                    result.error("bad_args", "missing file or busy", null)
                    return
                }
                pending = result
                pendingBytes = bytes
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mime
                    putExtra(Intent.EXTRA_TITLE, name)
                }
                start(intent, SAVE_REQUEST)
            }
            "pick" -> {
                if (pending != null) {
                    result.error("busy", "busy", null)
                    return
                }
                pending = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = call.argument<String>("mime") ?: "*/*"
                }
                start(intent, PICK_REQUEST)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(intent: Intent, code: Int) {
        try {
            activity.startActivityForResult(intent, code)
        } catch (e: Exception) {
            finish(null)
        }
    }

    /** MainActivity.onActivityResult 轉交；不是這裡的請求時回傳 false。 */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SAVE_REQUEST && requestCode != PICK_REQUEST) return false
        val uri: Uri? = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            finish(null)
            return true
        }
        try {
            if (requestCode == SAVE_REQUEST) {
                val bytes = pendingBytes
                activity.contentResolver.openOutputStream(uri, "wt")?.use { out ->
                    if (bytes != null) out.write(bytes)
                }
                finish(true)
            } else {
                val bytes = activity.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                // 備份檔很小；超過 20 MB 一定不是本 App 的備份。
                finish(if (bytes != null && bytes.size <= 20 * 1024 * 1024) bytes else null)
            }
        } catch (e: Exception) {
            finish(null)
        }
        return true
    }

    private fun finish(value: Any?) {
        val r = pending
        pending = null
        pendingBytes = null
        r?.success(value)
    }

    private fun safeName(name: String?): String? =
        name?.replace(Regex("[^A-Za-z0-9._-]"), "_")?.takeIf { it.isNotEmpty() && it.length <= 100 }

    companion object {
        private const val SAVE_REQUEST = 7101
        private const val PICK_REQUEST = 7102
    }
}
