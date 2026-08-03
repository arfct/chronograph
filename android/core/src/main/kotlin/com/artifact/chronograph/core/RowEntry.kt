package com.artifact.chronograph.core

import java.time.Instant

/**
 * Platform-free calendar item — what CalendarContract (or a test) feeds the
 * row builder. Counterpart of the EKCalendarItem surface TimelineEngine
 * consumes (title/start/end/allDay/calendar/location).
 */
data class CalendarItem(
    val id: String,
    val title: String?,
    val start: Instant,
    val end: Instant?,
    val isAllDay: Boolean = false,
    val calendarId: String = "",
    val calendarTitle: String = "",
    val location: String? = null,
    /** Mirrors EKEventStore.defaultCalendarForNewEvents membership on iOS. */
    val isDefaultCalendar: Boolean = true,
)

/**
 * Port of apple/Common/EventEntries.swift's EventEntry, trimmed to the fields
 * the builders and Glance rows use. Headers carry `dayIndex` instead of a
 * resolved forecast so the weather join can happen at render time (phase 3).
 */
class RowEntry(
    val id: String = "",
    val type: String? = null,
    var title: String? = null,
    var startAt: Instant? = null,
    var endAt: Instant? = null,
    var suffix: String? = null,
    val item: CalendarItem? = null,
    val allDayItems: MutableList<RowEntry>? = null,
    val children: MutableList<RowEntry>? = null,
    var removeIfOrphaned: Boolean = false,
    var locations: List<String>? = null,
    var meetingUrl: String? = null,
    var zoneId: String? = null,
    var dayIndex: Int? = null,
    var hasConflict: Boolean = false,
    var hasStartConflict: Boolean = false,
    var isFirstConflict: Boolean = false,
) {
    fun conflictsWith(other: RowEntry): Boolean {
        val end = endAt ?: return false
        if (item == null || other.item == null) return false
        val otherStart = other.startAt ?: return false
        return otherStart < end
    }

    fun hasEnded(at: Instant): Boolean = endAt?.isBefore(at) ?: false

    fun isHappening(at: Instant): Boolean {
        val start = startAt ?: return false
        val end = endAt ?: return false
        return at > start && at < end
    }
}

private val filteredReplacements = mapOf(
    "San Francisco" to "SF",
    "New York" to "NYC",
    "Los Angeles" to "LA",
    "Washington" to "DC",
    "London" to "LON",
)

/** Port of EventEntries.swift `clean(location:)`. */
fun cleanLocation(input: String): String {
    var result = input
        .replace(Regex("\\(.*?\\)|\\[.*?]"), "")
        .replace(Regex("\\s+"), " ")
    for ((key, value) in filteredReplacements) {
        result = result.replace(key, value)
    }
    return result.trim()
}

/** Port of StringProcessing.swift `splitAndTrim`. */
fun splitAndTrim(input: String, delimiter: Char = ','): List<String> =
    input.split(delimiter).map { it.trim() }.filter { it.isNotEmpty() }
