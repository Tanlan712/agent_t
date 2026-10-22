package io.github.tanlan712.valorant_shop_tracker

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 和 AndroidManifest.xml 的 activity-alias（Icon_<key>）及 AppIconId.key 一致。
    private val iconKeys = listOf("default", "editorial", "airy", "terminal", "eva_alert", "eva_monitor")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "valorant_shop_tracker/app_icon")
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
