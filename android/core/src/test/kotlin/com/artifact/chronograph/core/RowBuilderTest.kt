package com.artifact.chronograph.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.Instant
import java.time.ZoneId
import java.util.Locale

class RowBuilderTest {

    private val zone = ZoneId.of("America/Los_Angeles")
    private val locale = Locale.US

    // Wednesday 2026-08-05 09:00 PDT — fixed so headers/DST never drift.
    private val now = Instant.parse("2026-08-05T16:00:00Z")

    private fun event(
        id: String,
        title: String,
        start: Instant,
        durationMinutes: Long = 60,
        allDay: Boolean = false,
        calendarId: String = "work",
        calendarTitle: String = "Work",
        location: String? = null,
    ) = CalendarItem(
        id = id,
        title = title,
        start = start,
        end = start.plusSeconds(durationMinutes * 60),
        isAllDay = allDay,
        calendarId = calendarId,
        calendarTitle = calendarTitle,
        location = location,
    )

    private fun at(hourUtc: Int, minute: Int = 0, dayOffset: Long = 0): Instant =
        Instant.parse("2026-08-05T00:00:00Z").plusSeconds(dayOffset * 86400 + hourUtc * 3600L + minute * 60L)

    // MARK: timezones

    @Test
    fun `timezone rows sort by current offset and prettify titles`() {
        val rows = RowBuilder.timezoneRows(WidgetConfig.timezones, now)
        assertEquals(listOf("Los Angeles", "New York", "London", "Tokyo"), rows.map { it.title })
        assertEquals("timezone", rows.first().type)
        assertEquals("America/Los_Angeles", rows.first().zoneId)
    }

    @Test
    fun `timezone rows skip unknown zone ids and other content types`() {
        val config = WidgetConfig.timezones.copy(
            timezones = WidgetConfig.timezones.timezones + TimeZoneSelection("Not/AZone"),
        )
        assertEquals(4, RowBuilder.timezoneRows(config, now).size)
        assertTrue(RowBuilder.timezoneRows(WidgetConfig.calendar, now).isEmpty())
    }

    @Test
    fun `offset labels match the Swift format`() {
        assertEquals("+09:00", RowBuilder.offsetLabel("Asia/Tokyo", now))
        assertEquals("-07:00", RowBuilder.offsetLabel("America/Los_Angeles", now))
        assertEquals("+05:30", RowBuilder.offsetLabel("Asia/Kolkata", now))
    }

    // MARK: calendar headers

    @Test
    fun `day headers use Today, Tomorrow, then weekday names`() {
        val items = listOf(
            event("1", "Standup", at(17)),                 // today 10:00 PDT
            event("2", "Dinner", at(19, dayOffset = 1)),   // tomorrow 12:00 PDT
            event("3", "Review", at(18, dayOffset = 2)),   // Friday
        )
        val rows = RowBuilder.calendarRows(WidgetConfig.calendar, items, now, zone, locale)
        val headers = rows.filter { it.type == "header" }.map { it.title }
        assertEquals(listOf("Today", "Tomorrow", "Friday"), headers)
        assertEquals(listOf(0, 1, 2), rows.filter { it.type == "header" }.map { it.dayIndex })
    }

    @Test
    fun `filtered multi-day all-day events create no header for their day`() {
        val items = listOf(
            event("1", "Blocked day", at(17, dayOffset = 1), allDay = true),
            event("2", "Review", at(18, dayOffset = 2)),
        )
        // simpleCalendar shows all-day but not multi-day; make the all-day span two days so it filters.
        val multiDay = items[0].copy(end = items[0].start.plusSeconds(2 * 86400))
        val rows = RowBuilder.calendarRows(
            WidgetConfig.simpleCalendar, listOf(multiDay, items[1]), now, zone, locale,
        )
        assertEquals(1, rows.count { it.type == "header" })
        assertEquals("Friday", rows.first { it.type == "header" }.title)
    }

    @Test
    fun `all-day events live on the header, not as top-level rows`() {
        val items = listOf(
            event("1", "Conference", at(17), allDay = true),
            event("2", "Standup", at(18)),
        )
        val rows = RowBuilder.calendarRows(WidgetConfig.calendar, items, now, zone, locale)
        val header = rows.first { it.type == "header" }
        assertEquals(listOf("Conference"), header.allDayItems?.map { it.item?.title })
        assertFalse(header.removeIfOrphaned)
        assertEquals(listOf("Standup"), rows.filter { it.item != null && !it.item.isAllDay }.map { it.item?.title })
    }

    // MARK: dedup + suffix

    @Test
    fun `duplicate title in the same hour is dropped`() {
        val items = listOf(
            event("1", "Standup", at(17), calendarId = "work"),
            event("2", "Standup", at(17, 15), calendarId = "personal", calendarTitle = "Personal"),
            event("3", "Lunch", at(19)),
        )
        val rows = RowBuilder.calendarRows(WidgetConfig.calendar, items, now, zone, locale)
        assertEquals(listOf("Standup", "Lunch"), rows.mapNotNull { it.item?.title })
    }

    @Test
    fun `calendar-change suffix is the calendar's first letter`() {
        val items = listOf(
            event("1", "Standup", at(17), calendarId = "work", calendarTitle = "Work"),
            event("2", "Lunch", at(19), calendarId = "work", calendarTitle = "Work"),
            event("3", "Pickup", at(21), calendarId = "home", calendarTitle = "Family"),
        )
        val rows = RowBuilder.calendarRows(WidgetConfig.calendar, items, now, zone, locale)
        val byTitle = rows.filter { it.item != null }.associateBy { it.item?.title }
        assertEquals("W", byTitle["Standup"]?.suffix)
        assertNull(byTitle["Lunch"]?.suffix)
        assertEquals("F", byTitle["Pickup"]?.suffix)
    }

    // MARK: free time

    @Test
    fun `free-time row appears for gaps of 30 minutes or more with the deterministic strategy`() {
        val first = event("1", "Standup", at(17), durationMinutes = 30) // ends 17:30Z
        val second = event("2", "Review", at(19))                       // 90m gap
        val config = WidgetConfig.calendar.copy(features = WidgetConfig.calendar.features + WidgetFeature.FREE_TIME)
        val rows = RowBuilder.calendarRows(config, listOf(first, second), now, zone, locale)
        val free = rows.first { it.type == "free" }
        val priorEnd = first.end!!
        val expectedStrategy = obliqueStrategies[(priorEnd.epochSecond % obliqueStrategies.size).toInt()]
        assertEquals("1h 30m free - $expectedStrategy", free.title)
    }

    @Test
    fun `short gaps produce no free-time row`() {
        val first = event("1", "Standup", at(17), durationMinutes = 45)
        val second = event("2", "Review", at(18))
        val config = WidgetConfig.calendar.copy(features = WidgetConfig.calendar.features + WidgetFeature.FREE_TIME)
        val rows = RowBuilder.calendarRows(config, listOf(first, second), now, zone, locale)
        assertTrue(rows.none { it.type == "free" })
    }

    @Test
    fun `duration formatting matches DateComponentsFormatter abbreviated`() {
        assertEquals("2h", RowBuilder.formatDurationAbbreviated(7200))
        assertEquals("1h 30m", RowBuilder.formatDurationAbbreviated(5400))
        assertEquals("45m", RowBuilder.formatDurationAbbreviated(2700))
    }

    // MARK: locations

    @Test
    fun `locations are split, cleaned, and meeting urls extracted`() {
        val item = event(
            "1", "Sync", at(17),
            location = "https://zoom.us/j/123, San Francisco Office (3rd floor)",
        )
        val rows = RowBuilder.calendarRows(WidgetConfig.calendar, listOf(item), now, zone, locale)
        val entry = rows.first { it.item != null }
        assertEquals("https://zoom.us/j/123", entry.meetingUrl)
        assertEquals(listOf("SF Office"), entry.locations)
    }

    @Test
    fun `details are skipped for events more than four hours out`() {
        val item = event("1", "Far future", at(23), location = "Somewhere")
        val rows = RowBuilder.calendarRows(WidgetConfig.calendar, listOf(item), now, zone, locale)
        assertNull(rows.first { it.item != null }.locations)
    }

    // MARK: conflicts

    @Test
    fun `overlapping adjacent events are flagged, first conflict marked`() {
        val rows = listOf(
            RowEntry(id = "1", startAt = at(17), endAt = at(18, 30), item = event("1", "A", at(17), 90)),
            RowEntry(id = "2", startAt = at(18), endAt = at(19), item = event("2", "B", at(18))),
            RowEntry(id = "3", startAt = at(20), endAt = at(21), item = event("3", "C", at(20))),
        )
        RowBuilder.markConflicts(rows)
        assertTrue(rows[0].hasConflict)
        assertTrue(rows[0].isFirstConflict)
        assertTrue(rows[1].hasConflict)
        assertFalse(rows[1].isFirstConflict)
        assertFalse(rows[2].hasConflict)
        assertFalse(rows[1].hasStartConflict)
    }

    @Test
    fun `identical start times set hasStartConflict`() {
        val rows = listOf(
            RowEntry(id = "1", startAt = at(17), endAt = at(18), item = event("1", "A", at(17))),
            RowEntry(id = "2", startAt = at(17), endAt = at(19), item = event("2", "B", at(17), 120)),
        )
        RowBuilder.markConflicts(rows)
        assertTrue(rows[1].hasStartConflict)
    }

    @Test
    fun `headers never conflict with events`() {
        val rows = listOf(
            RowEntry(type = "header", title = "Today", startAt = at(7), endAt = at(7, dayOffset = 1)),
            RowEntry(id = "1", startAt = at(17), endAt = at(18), item = event("1", "A", at(17))),
        )
        RowBuilder.markConflicts(rows)
        assertFalse(rows[1].hasConflict)
    }

    // MARK: location cleaning

    @Test
    fun `location cleaning strips parentheticals and applies abbreviations`() {
        assertEquals("NYC Office", cleanLocation("New York Office (Floor 22)"))
        assertEquals("LON", cleanLocation("London [UK]"))
        assertEquals("Cafe", cleanLocation("  Cafe  "))
    }
}
