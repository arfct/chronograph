package com.artifact.chronograph.widget

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.updateAppWidgetState
import com.artifact.chronograph.core.FontSize

/**
 * App-wide settings, the Android counterpart of the App Group defaults on iOS
 * (`Keys.defaultFontSize`). Per-widget options stay in [WidgetPrefs].
 */
object AppPrefs {
    private const val FILE = "chronograph"
    private const val DEFAULT_FONT_SIZE = "defaultFontSize"

    /** The size widgets set to Default use. Medium when unset. */
    fun defaultFontSize(context: Context): FontSize =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(DEFAULT_FONT_SIZE, null)
            ?.let { runCatching { FontSize.valueOf(it) }.getOrNull() }
            ?: FontSize.MEDIUM

    /**
     * Saves the default and redraws every placed widget. A running Glance
     * session only recomposes on `update`, so the size is also copied into each
     * widget's state ([WidgetPrefs.APP_DEFAULT_SIZE]), which the widgets read
     * inside composition.
     */
    suspend fun setDefaultFontSize(context: Context, size: FontSize) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(DEFAULT_FONT_SIZE, size.name)
            .apply()
        val manager = GlanceAppWidgetManager(context)
        val widgets: List<Pair<Class<out GlanceAppWidget>, GlanceAppWidget>> = listOf(
            CalendarWidget::class.java to CalendarWidget(),
            TimeZonesWidget::class.java to TimeZonesWidget(),
        )
        for ((type, widget) in widgets) {
            for (id in manager.getGlanceIds(type)) {
                updateAppWidgetState(context, id) { it[WidgetPrefs.APP_DEFAULT_SIZE] = size.name }
                widget.update(context, id)
            }
        }
    }
}
