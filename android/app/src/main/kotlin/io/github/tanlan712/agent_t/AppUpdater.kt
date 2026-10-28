package io.github.tanlan712.agent_t

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * App 內更新（channel `agent_t/app_update`，AGENTS.md 第 3 節「手機 App」）：
 * 下載 GitHub Release 的 Agent-T.apk 到 App 自己的快取資料夾，檢查 SHA-256 與簽章後交給系統安裝程式。
 * 只連 Dart 傳進來的 github.com Release 網址，不帶任何帳號資料。
 */
class AppUpdater(private val activity: Activity, private val channel: MethodChannel) {
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var downloading = false

    private val apkFile get() = File(File(activity.cacheDir, "updates"), "Agent-T.apk")

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> {
                // App 啟動時呼叫：上次下載的 APK 已經裝好或不用了，刪掉省空間。
                if (!downloading) apkFile.delete()
                result.success(mapOf("build" to versionCode(installedInfo())))
            }
            "download" -> {
                val url = call.argument<String>("url")
                if (url == null || !url.startsWith("https://github.com/")) {
                    result.error("bad_url", "unexpected url", null)
                } else if (downloading) {
                    result.error("busy", "already downloading", null)
                } else {
                    download(url, call.argument<String>("sha256"), result)
                }
            }
            "canInstall" -> result.success(canInstall())
            "openInstallSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${activity.packageName}")))
                }
                result.success(null)
            }
            "install" -> {
                val file = apkFile
                if (!file.exists()) {
                    result.error("missing", "apk not downloaded", null)
                } else {
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                    activity.startActivity(Intent(Intent.ACTION_VIEW)
                        .setDataAndType(uri, "application/vnd.android.package-archive")
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity.packageManager.canRequestPackageInstalls()

    // 在背景執行緒下載；進度與結果回到主執行緒。
    private fun download(url: String, sha256: String?, result: MethodChannel.Result) {
        downloading = true
        Thread {
            val file = apkFile
            try {
                file.parentFile?.mkdirs()
                file.delete()
                val conn = URL(url).openConnection() as HttpURLConnection
                conn.connectTimeout = 15000
                conn.readTimeout = 30000
                conn.instanceFollowRedirects = true
                conn.connect()
                if (conn.responseCode != 200) throw IllegalStateException("HTTP ${conn.responseCode}")
                val total = conn.contentLengthLong
                val digest = MessageDigest.getInstance("SHA-256")
                var received = 0L
                var lastReport = 0L
                conn.inputStream.use { input ->
                    file.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            output.write(buffer, 0, n)
                            digest.update(buffer, 0, n)
                            received += n
                            val now = System.currentTimeMillis()
                            if (now - lastReport > 200) {
                                lastReport = now
                                val r = received
                                main.post { channel.invokeMethod("progress", mapOf("received" to r, "total" to total)) }
                            }
                        }
                    }
                }
                conn.disconnect()
                val actual = hex(digest.digest())
                if (sha256 != null && !sha256.equals(actual, ignoreCase = true)) {
                    file.delete()
                    throw IllegalStateException("checksum mismatch")
                }
                val archive = archiveInfo(file)
                val installed = installedInfo()
                val apkSigs = signatures(archive)
                val mySigs = signatures(installed)
                val reply = mapOf(
                    "build" to versionCode(archive),
                    "package" to archive?.packageName,
                    // null：讀不到簽章，交給系統安裝程式判斷。
                    "sameSignature" to if (apkSigs == null || mySigs == null) null else apkSigs.toSet() == mySigs.toSet())
                main.post {
                    downloading = false
                    result.success(reply)
                }
            } catch (e: Exception) {
                file.delete()
                main.post {
                    downloading = false
                    result.error("download_failed", e.javaClass.simpleName + ": " + (e.message ?: ""), null)
                }
            }
        }.start()
    }

    private fun installedInfo(): PackageInfo? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            activity.packageManager.getPackageInfo(activity.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.getPackageInfo(activity.packageName, PackageManager.GET_SIGNATURES)
        }
    } catch (e: Exception) {
        null
    }

    private fun archiveInfo(file: File): PackageInfo? {
        val pm = activity.packageManager
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pm.getPackageArchiveInfo(file.path, PackageManager.GET_SIGNING_CERTIFICATES)
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageArchiveInfo(file.path, PackageManager.GET_SIGNATURES)
        }
        info?.applicationInfo?.let {
            it.sourceDir = file.path
            it.publicSourceDir = file.path
        }
        return info
    }

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo?): Long? = when {
        info == null -> null
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.P -> info.longVersionCode
        else -> info.versionCode.toLong()
    }

    // 簽章憑證的 SHA-256（只用來比對新舊版是否同一把金鑰）。
    private fun signatures(info: PackageInfo?): List<String>? {
        if (info == null) return null
        val sigs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            info.signatures
        }
        if (sigs.isNullOrEmpty()) return null
        return sigs.map { hex(MessageDigest.getInstance("SHA-256").digest(it.toByteArray())) }
    }

    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }
}
