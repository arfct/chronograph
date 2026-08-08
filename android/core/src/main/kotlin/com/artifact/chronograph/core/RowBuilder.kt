package com.artifact.chronograph.core

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

/**
 * Port of TimelineEngine's row builders (apple/Common/WidgetTimeline.swift):
 * buildTimezoneEntries, buildCalendarEntries, and the adjacent-pair conflict
 * pass from `timeline()`. Reminders and the notes/attachment extraction are
 * intentionally absent — see docs/parity.md.
 */
object RowBuilder {

    fun timezoneRows(config: WidgetConfig, now: Instant = Instant.now()): List<RowEntry> {
        if (config.content != DisplayedContent.TIMEZONES) return emptyList()

        return config.timezones
            .mapNotNull { runCatching { ZoneId.of(it.id) }.getOrNull() }
            .sortedBy { it.rules.getOffset(now).totalSeconds }
            .map { zone ->
                RowEntry(
                    type = "timezone",
                    title = zone.id.substringAfterLast("/").replace("_", " "),
                    zoneId = zone.id,
                )
            }
    }

    fun calendarRows(
        config: WidgetConfig,
        items: List<CalendarItem>,
        renderDate: Instant,
        zone: ZoneId = ZoneId.systemDefault(),
        locale: Locale = Locale.getDefault(),
    ): List<RowEntry> {
        val showAllDay = WidgetFeature.ALL_DAY_EVENTS in config.features
        val showMultiDay = WidgetFeature.MULTI_DAY_EVENTS in config.features

        val entries = mutableListOf<RowEntry>()
        var previousItem: CalendarItem? = null
        var headerIndex = -1

        for (item in items) {
            val lastDay = previousItem?.let { localDate(maxOf(renderDate, it.start), zone) }
            val thisDate = maxOf(renderDate, item.start)
            val dateHasChanged = lastDay != localDate(thisDate, zone)

            if (item.isAllDay) {
                if (!showAllDay) continue
                if (!showMultiDay && item.end != null &&
                    localDate(item.start, zone) != localDate(item.end, zone)
                ) continue
            }

            if (dateHasChanged) {
                if (headerIndex >= 0 && entries[headerIndex].children?.isEmpty() == true) {
                    entries.removeAt(headerIndex)
                }

                val today = localDate(renderDate, zone)
                val headerDay = localDate(thisDate, zone)
                val title = when (headerDay) {
                    today -> "Today"
                    today.plusDays(1) -> "Tomorrow"
                    else -> headerDay.dayOfWeek.getDisplayName(TextStyle.FULL, locale)
                }
                val dayIndex = max(0, (localDate(item.start, zone).toEpochDay() - today.toEpochDay()).toInt())

                val header = RowEntry(
                    type = "header",
                    title = title,
                    startAt = headerDay.atStartOfDay(zone).toInstant(),
                    endAt = localDate(item.start, zone).atStartOfDay(zone).plusDays(1).toInstant(),
                    allDayItems = mutableListOf(),
                    children = mutableListOf(),
                    removeIfOrphaned = true,
                    dayIndex = dayIndex,
                )
                headerIndex = entries.size
                entries.add(header)
            } else if (WidgetFeature.FREE_TIME in config.features) {
                val priorEnd = previousItem?.end ?: renderDate
                val gapSeconds = item.start.epochSecond - priorEnd.epochSecond
                // Same banker's rounding to 15-minute increments as the Swift engine.
                val rounded = (Math.rint(gapSeconds / 900.0) * 900.0).toLong()
                if (rounded >= 30 * 60) {
                    val strategy = obliqueStrategies[(priorEnd.epochSecond % obliqueStrategies.size).toInt()]
                    entries.add(
                        RowEntry(
                            type = "free",
                            title = "${formatDurationAbbreviated(rounded)} free - $strategy",
                            startAt = priorEnd,
                            endAt = thisDate,
                        )
                    )
                }
            }

            // Skip duplicates: same title starting in the same hour as the previous item.
            val prev = previousItem
            if (prev != null && item.title == prev.title && sameHour(item.start, prev.start, zone)) {
                continue
            }

            val entry = RowEntry(
                id = item.id,
                startAt = item.start,
                endAt = item.end,
                item = item,
            )

            if (item.calendarId != prev?.calendarId) {
                entry.suffix = item.calendarTitle.take(1)
            }

            if (item.isAllDay) {
                entries[headerIndex].allDayItems?.add(0, entry)
                entries[headerIndex].children?.add(0, entry)
                entries[headerIndex].removeIfOrphaned = false
            } else {
                entries[headerIndex].children?.add(0, entry)

                val fetchDetails = item.start < renderDate.plusSeconds(4 * 3600)
                if (fetchDetails && !item.location.isNullOrEmpty()) {
                    val locations = splitAndTrim(item.location)
                    val urls = locations.filter { it.startsWith("http://") || it.startsWith("https://") }
                    entry.meetingUrl = urls.firstOrNull()
                    entry.locations = locations.filterNot { it in urls }.map(::cleanLocation)
                }
                if (fetchDetails && !item.description.isNullOrEmpty()) {
                    attachDescription(entry, item.description)
                }

                entries.add(entry)
            }

            previousItem = item
        }

        return entries
    }

    /**
     * The description half of TimelineEngine's detail block: strip the
     * machine-generated boilerplate, lift out document links, keep the meeting
     * link separate, and leave `notes` null when nothing human survived.
     */
    private fun attachDescription(entry: RowEntry, description: String) {
        val note = cleanEventNote(description)

        val (links, remainder) = extractAttachments(note)
        // Conferencing and mail links are plumbing, not documents: the meeting
        // link gets its own row and the rest is noise.
        entry.attachments = links
            .filterNot { link -> noteNoiseLinkHosts.any { link.urlString.contains(it, ignoreCase = true) } }
            .takeIf { it.isNotEmpty() }

        if (entry.meetingUrl == null) {
            extractMeetingUrls(description).firstOrNull()?.let {
                entry.meetingUrl = it.urlString
                entry.meetingTitle = it.displayName
            }
        } else if (entry.meetingTitle == null) {
            entry.meetingTitle = titleFromUrl(entry.meetingUrl!!)
        }

        entry.notes = cleanEventNote(stripHtmlTags(remainder)).takeIf { it.isNotEmpty() }
    }

    /** The adjacent-pair conflict pass from TimelineEngine.timeline(). */
    fun markConflicts(entries: List<RowEntry>) {
        for (i in 0 until entries.size - 1) {
            val entry = entries[i]
            val next = entries[i + 1]
            if (entry.conflictsWith(next)) {
                if (!entry.hasConflict) entry.isFirstConflict = true
                entry.hasConflict = true
                next.hasConflict = true
                if (entry.startAt == next.startAt) next.hasStartConflict = true
            }
        }
    }

    /** UTC-offset label like "+09:00" / "-07:00" for a zone at an instant. */
    fun offsetLabel(zoneId: String, now: Instant): String {
        val offset = ZoneId.of(zoneId).rules.getOffset(now).totalSeconds
        val sign = if (offset >= 0) "+" else "-"
        return "%s%02d:%02d".format(sign, abs(offset / 3600), abs((offset % 3600) / 60))
    }

    /** Matches DateComponentsFormatter(.abbreviated, [.hour, .minute]): "2h", "1h 30m", "45m". */
    internal fun formatDurationAbbreviated(seconds: Long): String {
        val hours = seconds / 3600
        val minutes = (seconds % 3600) / 60
        return when {
            hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
            hours > 0 -> "${hours}h"
            else -> "${minutes}m"
        }
    }

    private fun localDate(instant: Instant, zone: ZoneId): LocalDate =
        instant.atZone(zone).toLocalDate()

    private fun sameHour(a: Instant, b: Instant, zone: ZoneId): Boolean {
        val za = a.atZone(zone)
        val zb = b.atZone(zone)
        return za.toLocalDate() == zb.toLocalDate() && za.hour == zb.hour
    }
}
