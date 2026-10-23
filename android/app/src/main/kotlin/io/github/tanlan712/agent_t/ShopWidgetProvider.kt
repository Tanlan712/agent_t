package io.github.tanlan712.agent_t

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/// 主畫面小工具：今天的每日商店（4 款名稱與價格）與刷新倒數。
/// 資料由 App 同步商店後經 agent_t/home_widget channel 傳進來，只存在這支手機；
/// 小工具自己不連網、不登入（AGENTS.md 第 3 節）。
class ShopWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS = "agent_t_home_widget"
        private const val KEY = "shop"
        private val lineIds = intArrayOf(R.id.widget_line1, R.id.widget_line2, R.id.widget_line3, R.id.widget_line4)

        fun save(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
            refreshAll(context)
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ShopWidgetProvider::class.java))
            for (id in ids) manager.updateAppWidget(id, build(context))
        }

        private fun remaining(ms: Long): String {
            if (ms <= 0) return "已過期，打開 App 更新"
            val minutes = ms / 60000
            return "刷新倒數 ${minutes / 60} 小時 ${minutes % 60} 分"
        }

        private fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.shop_widget)
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            val json = try { raw?.let { JSONObject(it) } } catch (_: Exception) { null }
            val lines = json?.optJSONArray("lines")
            if (json == null || lines == null || lines.length() == 0) {
                views.setTextViewText(R.id.widget_status, "打開 App 登入並同步商店")
                for (id in lineIds) views.setViewVisibility(id, View.GONE)
                return views
            }
            val expires = json.optLong("expiresAt", 0L)
            views.setTextViewText(R.id.widget_status, remaining(expires - System.currentTimeMillis()))
            for ((i, id) in lineIds.withIndex()) {
                if (i < lines.length()) {
                    val line = lines.getJSONObject(i)
                    views.setTextViewText(id, "${line.optString("name")}　${line.optInt("price")} VP")
                    views.setViewVisibility(id, View.VISIBLE)
                } else {
                    views.setViewVisibility(id, View.GONE)
                }
            }
            val night = json.optString("night", "")
            views.setTextViewText(R.id.widget_night, night)
            views.setViewVisibility(R.id.widget_night, if (night.isEmpty()) View.GONE else View.VISIBLE)
            return views
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context))
    }
}
