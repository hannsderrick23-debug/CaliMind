package com.calimind.calimind

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class CaliMindWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.calimind_widget).apply {
                val voiceIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("io.supabase.calimind://voice-capture"),
                )
                setOnClickPendingIntent(R.id.widget_root, voiceIntent)
                setOnClickPendingIntent(R.id.widget_voice_shortcut, voiceIntent)

                val title = widgetData.getString("next_task_title", null)
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
                setTextViewText(
                    R.id.widget_task_title,
                    title ?: context.getString(R.string.widget_generic_title),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
