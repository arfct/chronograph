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
    /** Raw event description, boilerplate and all — cleaned by the row builder. */
    val description: String? = null,
    /** Mirrors EKEventStore.defaultCalendarForNewEvents membership on iOS. */
    val isDefaultCalendar: Boolean = true,
    /** Short names of the attendees other than the calendar's owner (FacePile). */
    val attendeeNames: List<String> = emptyList(),
    /** Every attendee, the owner included — FacePile's trailing count. */
    val attendeeCount: Int = 0,
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
    /** Meeting link title ("Zoom", "Meet") for the video row. */
    var meetingTitle: String? = null,
    /** Document links pulled out of the description. */
    var attachments: List<EventAttachment>? = null,
    /** The human part of the description, or null when nothing survived. */
    var notes: String? = null,
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

    val hasLocation: Boolean get() = !locations.isNullOrEmpty()

    /** EventEntry.hasNotes: a note survived boilerplate stripping. */
    val hasNotes: Boolean get() = (notes?.length ?: 0) > 1

    val hasAttachments: Boolean get() = !attachments.isNullOrEmpty()

    /** FacePile draws its line only above two attendees. */
    val showsAttendees: Boolean get() = (item?.attendeeCount ?: 0) > 2

    /** EventEntry.isSoon: starts within two hours (or already has). */
    fun isSoon(at: Instant): Boolean {
        val start = startAt ?: return false
        return start.epochSecond - at.epochSecond < 2 * 3600
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
