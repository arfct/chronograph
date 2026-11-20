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
    /** Copy of [AppPrefs.defaultFontSize], written so a running widget recomposes. */
    val APP_DEFAULT_SIZE = stringPreferencesKey("appDefaultFontSize")
    val OBFUSCATION = stringPreferencesKey("obfuscation")
    val TRANSPARENT_BACKGROUND = booleanPreferencesKey("transparentBackground")
    val ACCENT_COLOR = stringPreferencesKey("accentColor")
    val ALL_DAY_EVENTS = booleanPreferencesKey("allDayEvents")
    val MULTI_DAY_EVENTS = booleanPreferencesKey("multiDayEvents")
    val TIME_BARS = booleanPreferencesKey("timeBars")
    val FREE_TIME = booleanPreferencesKey("freeTime")

    /** Stored in [FONT_SIZE] when the widget follows the app-wide default. */
    const val DEFAULT_SIZE = "DEFAULT"

    /** True when the widget has no size of its own and uses [AppPrefs.defaultFontSize]. */
    fun usesDefaultSize(prefs: Preferences): Boolean =
        prefs[FONT_SIZE]?.let { runCatching { FontSize.valueOf(it) }.getOrNull() } == null

    /** The app-wide default as last copied into this widget's state, if any. */
    fun appDefaultSize(prefs: Preferences): FontSize? =
        prefs[APP_DEFAULT_SIZE]?.let { runCatching { FontSize.valueOf(it) }.getOrNull() }

    /** The widget's own size, or [default] when it follows the app-wide default. */
    fun fontSize(prefs: Preferences, default: FontSize): FontSize =
        prefs[FONT_SIZE]?.let { runCatching { FontSize.valueOf(it) }.getOrNull() } ?: default

    fun obfuscation(prefs: Preferences): ObfuscationStyle =
        prefs[OBFUSCATION]?.let { runCatching { ObfuscationStyle.valueOf(it) }.getOrNull() }
            ?: ObfuscationStyle.NONE

    /**
     * Transparent by default, matching iOS: `WidgetConfig.backgroundColor` is ""
     * there, which resolves to `.clear`, and the widget goes full bleed.
     */
    fun isTransparent(prefs: Preferences): Boolean = prefs[TRANSPARENT_BACKGROUND] != false

    fun calendarConfig(prefs: Preferences, defaultSize: FontSize): WidgetConfig {
        val features = buildSet {
            if (prefs[ALL_DAY_EVENTS] != false) add(WidgetFeature.ALL_DAY_EVENTS)
            if (prefs[MULTI_DAY_EVENTS] != false) add(WidgetFeature.MULTI_DAY_EVENTS)
            if (prefs[TIME_BARS] != false) add(WidgetFeature.TIME_BARS)
            if (prefs[FREE_TIME] == true) add(WidgetFeature.FREE_TIME)
        }
        return WidgetConfig.calendar.copy(
            features = features,
            fontSize = fontSize(prefs, defaultSize),
            obfuscation = obfuscation(prefs),
            accentColor = prefs[ACCENT_COLOR] ?: "",
        )
    }

    fun timezonesConfig(prefs: Preferences, defaultSize: FontSize): WidgetConfig =
        WidgetConfig.timezones.copy(
            fontSize = fontSize(prefs, defaultSize),
            obfuscation = obfuscation(prefs),
        )
}
