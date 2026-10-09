package com.thavika.thavika

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// The home-screen widget: what is safe to spend today, and a + button that
/// opens the add screen. The text is written by the app (see
/// lib/features/widget/widget_sync.dart) so it follows the app language.
class ThavikaWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.thavika_widget).apply {
                setTextViewText(
                    R.id.widget_label,
                    widgetData.getString("widget_label", null)
                        ?: context.getString(R.string.widget_label_default),
                )
                setTextViewText(
                    R.id.widget_amount,
                    widgetData.getString("widget_amount", null)
                        ?: context.getString(R.string.widget_amount_default),
                )
                setOnClickPendingIntent(
                    R.id.widget_add,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("thavika://add"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("thavika://open"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
