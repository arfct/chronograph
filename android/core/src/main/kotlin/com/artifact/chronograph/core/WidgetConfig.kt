package com.artifact.chronograph.core

/**
 * Android counterpart of apple/Common/WidgetConfig.swift +
 * ConfigurationIntent.swift's enums. Reminders are absent by design
 * (docs/parity.md) and Ishihara is handled in Obfuscation.kt.
 */
enum class DisplayedContent { CALENDAR, TIMEZONES, WEATHER }

enum class WidgetFeature { ALL_DAY_EVENTS, MULTI_DAY_EVENTS, WEATHER, TIME_BARS, FREE_TIME }

enum class WeatherStyle { CURRENT, HOURLY, DAILY }

enum class FontStyle { NORMAL, ROUNDED, SERIF, MONOSPACE, CONDENSED, COMPRESSED }

enum class WidgetViewOption { SHOW_COLORS, FULL_BLEED }

data class TimeZoneSelection(val id: String, val title: String? = null)

data class WidgetConfig(
    val content: DisplayedContent = DisplayedContent.CALENDAR,
    val features: Set<WidgetFeature> = emptySet(),
    val calendarIds: List<String> = emptyList(),
    val timezones: List<TimeZoneSelection> = emptyList(),
    val weatherStyle: WeatherStyle = WeatherStyle.CURRENT,
    /** Empty string means current location; otherwise a zip/postal code. */
    val weatherLocation: String = "",
    val viewOptions: Set<WidgetViewOption> = emptySet(),
    val fontStyle: FontStyle = FontStyle.NORMAL,
    val fontSize: FontSize = FontSize.MEDIUM,
    val backgroundColor: String = "",
    val accentColor: String = "",
    val obfuscation: ObfuscationStyle = ObfuscationStyle.NONE,
) {
    companion object {
        val calendar = WidgetConfig(
            content = DisplayedContent.CALENDAR,
            features = setOf(
                WidgetFeature.ALL_DAY_EVENTS,
                WidgetFeature.TIME_BARS,
                WidgetFeature.MULTI_DAY_EVENTS,
            ),
        )
        val simpleCalendar = WidgetConfig(
            content = DisplayedContent.CALENDAR,
            features = setOf(WidgetFeature.ALL_DAY_EVENTS),
        )
        val combo = calendar.copy(features = calendar.features + WidgetFeature.WEATHER)
        val timezones = WidgetConfig(
            content = DisplayedContent.TIMEZONES,
            timezones = listOf(
                TimeZoneSelection("America/Los_Angeles", "Los Angeles"),
                TimeZoneSelection("America/New_York", "New York City"),
                TimeZoneSelection("Europe/London", "London"),
                TimeZoneSelection("Asia/Tokyo", "Tokyo"),
            ),
        )
        val weatherCurrent = WidgetConfig(content = DisplayedContent.WEATHER, weatherStyle = WeatherStyle.CURRENT)
        val weatherDaily = WidgetConfig(content = DisplayedContent.WEATHER, weatherStyle = WeatherStyle.DAILY)
    }
}
