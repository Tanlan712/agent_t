package io.github.tanlan712.agent_t

import android.content.ComponentName
import android.content.pm.PackageManager
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 和 AndroidManifest.xml 的 activity-alias（Icon_<key>）及 AppIconId.key 一致。
    private val iconKeys = listOf("default", "editorial", "airy", "terminal", "eva_alert", "eva_monitor")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "agent_t/app_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getIcon" -> result.success(currentIcon())
                    "setIcon" -> {
                        val key = call.arguments as? String
                        if (key == null || key !in iconKeys) {
                            result.error("bad_icon", "unknown icon", null)
                        } else {
                            setIcon(key)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        configureHomeWidget(flutterEngine)
        // App 內更新：下載 GitHub Release 的新版 APK 並交給系統安裝（AppUpdater.kt）。
        val updateChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "agent_t/app_update")
        val updater = AppUpdater(this, updateChannel)
        updateChannel.setMethodCallHandler(updater::handle)
        // 多帳號切換：讀出／放回內嵌頁的 Riot 登入 cookie（ssid）。只在 App 與 WebView 之間傳遞，不寫 log
        // （使用者決定 2026-10-23，AGENTS.md 第 3 節）。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "agent_t/riot_cookies")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(readSsid())
                    "write" -> {
                        val ssid = call.arguments as? String
                        if (ssid.isNullOrEmpty() || ssid.contains(';')) {
                            result.error("bad_cookie", "invalid cookie", null)
                        } else {
                            writeSsid(ssid) { result.success(null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // 主畫面小工具的資料（今天的商店名稱、價格與到期時間；不含 token）。
    private fun configureHomeWidget(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "agent_t/home_widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val json = call.arguments as? String
                        if (json == null) {
                            result.error("bad_data", "missing data", null)
                        } else {
                            ShopWidgetProvider.save(applicationContext, json)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private val riotAuthUrl = "https://auth.riotgames.com"

    private fun readSsid(): String? = CookieManager.getInstance().getCookie(riotAuthUrl)
        ?.split(';')
        ?.map { it.trim() }
        ?.firstOrNull { it.startsWith("ssid=") }
        ?.removePrefix("ssid=")
        ?.takeIf { it.isNotEmpty() }

    private fun writeSsid(ssid: String, done: () -> Unit) {
        val manager = CookieManager.getInstance()
        manager.setCookie(riotAuthUrl, "ssid=$ssid; Path=/; Secure; HttpOnly") {
            manager.flush()
            done()
        }
    }

    private fun alias(key: String) = ComponentName(packageName, "${MainActivity::class.java.name.substringBeforeLast('.')}.Icon_$key")

    private fun currentIcon(): String = iconKeys.firstOrNull { key ->
        when (packageManager.getComponentEnabledSetting(alias(key))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            // 沒改過時以 manifest 為準：只有 default 預設啟用。
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> key == "default"
            else -> false
        }
    } ?: "default"

    // 先啟用新的再停用其他的，桌面上隨時至少有一個入口。
    private fun setIcon(key: String) {
        val pm = packageManager
        pm.setComponentEnabledSetting(alias(key), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        for (other in iconKeys) {
            if (other != key) {
                pm.setComponentEnabledSetting(alias(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        }
    }
}
