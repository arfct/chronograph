package com.artifact.chronograph.widget

import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.artifact.chronograph.core.FontSize
import com.artifact.chronograph.core.ObfuscationStyle
import com.artifact.chronograph.core.WidgetConfig
import com.artifact.chronograph.core.WidgetFeature

/**
 * Per-widget options stored in Glance's per-glanceId preference state —
 * the Android counterpart of the per-widget AppIntents parameters on iOS.
 * Absent keys fall back to the iOS preset defaults.
 */
object WidgetPrefs {
    val FONT_SIZE = stringPreferencesKey("fontSize")
    val OBFUSCATION = stringPreferencesKey("obfuscation")
    val TRANSPARENT_BACKGROUND = booleanPreferencesKey("transparentBackground")
    val ACCENT_COLOR = stringPreferencesKey("accentColor")
    val ALL_DAY_EVENTS = booleanPreferencesKey("allDayEvents")
    val MULTI_DAY_EVENTS = booleanPreferencesKey("multiDayEvents")
    val TIME_BARS = booleanPreferencesKey("timeBars")
    val FREE_TIME = booleanPreferencesKey("freeTime")

    fun fontSize(prefs: Preferences): FontSize =
        prefs[FONT_SIZE]?.let { runCatching { FontSize.valueOf(it) }.getOrNull() } ?: FontSize.MEDIUM

    fun obfuscation(prefs: Preferences): ObfuscationStyle =
        prefs[OBFUSCATION]?.let { runCatching { ObfuscationStyle.valueOf(it) }.getOrNull() }
            ?: ObfuscationStyle.NONE

    fun isTransparent(prefs: Preferences): Boolean = prefs[TRANSPARENT_BACKGROUND] == true

    fun calendarConfig(prefs: Preferences): WidgetConfig {
        val features = buildSet {
            if (prefs[ALL_DAY_EVENTS] != false) add(WidgetFeature.ALL_DAY_EVENTS)
            if (prefs[MULTI_DAY_EVENTS] != false) add(WidgetFeature.MULTI_DAY_EVENTS)
            if (prefs[TIME_BARS] != false) add(WidgetFeature.TIME_BARS)
            if (prefs[FREE_TIME] == true) add(WidgetFeature.FREE_TIME)
        }
        return WidgetConfig.calendar.copy(
            features = features,
            fontSize = fontSize(prefs),
            obfuscation = obfuscation(prefs),
            accentColor = prefs[ACCENT_COLOR] ?: "",
        )
    }

    fun timezonesConfig(prefs: Preferences): WidgetConfig =
        WidgetConfig.timezones.copy(
            fontSize = fontSize(prefs),
            obfuscation = obfuscation(prefs),
        )
}
