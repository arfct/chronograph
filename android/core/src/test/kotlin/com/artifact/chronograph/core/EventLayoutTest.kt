package com.artifact.chronograph.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.Instant

class EventLayoutTest {
    private val now = Instant.parse("2026-11-19T23:30:00Z")
    // .body on a tall widget: fontSize 17, lineHeight 33, small line 21.78.
    private val metrics = RowMetrics.forWidget(FontSize.MEDIUM, widgetHeightDp = 400f)
    // A phone-width title column: 17 * 0.55 = 9.35 per character → 29 chars.
    private val column = 280f

    private fun row(
        title: String,
        startInMinutes: Long = 10,
        locations: List<String>? = null,
        notes: String? = null,
        attachments: List<EventAttachment>? = null,
        attendees: Int = 0,
    ): RowEntry {
        val start = now.plusSeconds(startInMinutes * 60)
        val item = CalendarItem(
            id = "1", title = title, start = start, end = start.plusSeconds(1800),
            attendeeNames = List(maxOf(0, attendees - 1)) { "Person$it" },
            attendeeCount = attendees,
        )
        return RowEntry(
            id = "1", startAt = start, endAt = start.plusSeconds(1800), item = item,
            locations = locations, notes = notes, attachments = attachments,
        )
    }

    @Test
    fun `characters per line uses a 0_55 em mean advance with a floor of eight`() {
        assertEquals(29, EventLayout.charactersPerLine(column, 17f))
        assertEquals(8, EventLayout.charactersPerLine(10f, 17f))
    }

    @Test
    fun `a long title that is soon gets two text lines of height`() {
        val title = "Muse WatchOS, WearOS Live workout experience"
        assertTrue(EventLayout.titleWraps(title, column, metrics, expanded = true))
        // max(lineHeight, 2 * lineHeight / 1.5): two unspread text lines.
        assertEquals(44f, EventLayout.titleHeight(metrics, wraps = true), 0.001f)
        assertEquals(44f, EventLayout.eventHeight(row(title), now, column, metrics, false), 0.001f)
    }

    @Test
    fun `titles stay one line when far off, short, or height is limited`() {
        val title = "Muse WatchOS, WearOS Live workout experience"
        assertFalse(EventLayout.titleWraps(title, column, metrics, expanded = false))
        assertFalse(EventLayout.titleWraps("Muse Design Review", column, metrics, expanded = true))
        // Three hours out is neither happening nor soon.
        assertEquals(33f, EventLayout.eventHeight(row(title, startInMinutes = 180), now, column, metrics, false))
        assertEquals(33f, EventLayout.eventHeight(row(title), now, column, metrics, heightIsLimited = true))
    }

    @Test
    fun `detail block counts location, every attachment, attendees and the note`() {
        val docs = listOf(
            EventAttachment("https://docs.google.com/document/d/a", prefix = "1"),
            EventAttachment("https://docs.google.com/document/d/b", prefix = "2"),
        )
        val r = row(
            "Muse Design Review",
            locations = listOf("SF - 250-30"),
            attachments = docs,
            attendees = 4,
            notes = "Short note",
        )
        val small = metrics.smallLineHeight
        // location + 2 docs + attendees = 4 lines, one-line note.
        assertEquals(5 * small, EventLayout.detailHeight(r, column, metrics), 0.001f)
        assertEquals(
            33f + 5 * small + small / 3f,
            EventLayout.eventHeight(r, now, column, metrics, false), 0.001f,
        )
    }

    @Test
    fun `attendee line is counted only when FacePile draws it`() {
        val two = row("Sync", locations = listOf("Room"), attendees = 2)
        val three = row("Sync", locations = listOf("Room"), attendees = 3)
        assertEquals(metrics.smallLineHeight, EventLayout.detailHeight(two, column, metrics), 0.001f)
        assertEquals(2 * metrics.smallLineHeight, EventLayout.detailHeight(three, column, metrics), 0.001f)
    }

    @Test
    fun `a note wraps on a newline or by length, to two unspread small lines`() {
        assertTrue(EventLayout.noteWraps("one\ntwo", column, metrics))
        assertFalse(EventLayout.noteWraps("Bring snacks.", column, metrics))
        assertTrue(EventLayout.noteWraps("x".repeat(60), column, metrics))
        val small = metrics.smallLineHeight
        assertEquals(2 * small / 1.5f, EventLayout.noteHeight(metrics, wraps = true), 0.001f)
    }

    @Test
    fun `details need something to show and the row to be expanded`() {
        assertFalse(EventLayout.detailsVisible(row("Bare"), expanded = true))
        assertTrue(EventLayout.detailsVisible(row("Here", locations = listOf("Room")), expanded = true))
        assertFalse(EventLayout.detailsVisible(row("Here", locations = listOf("Room")), expanded = false))
        // A one-character note is not a note (EventEntry.hasNotes).
        assertFalse(EventLayout.detailsVisible(row("Here", notes = "."), expanded = true))
    }

    @Test
    fun `extractEmoji moves emoji-presentation graphemes out of the title`() {
        assertEquals("🎉" to "Launch party", EventLayout.extractEmoji("🎉 Launch party"))
        assertEquals("👩‍💻" to "Pairing", EventLayout.extractEmoji("Pairing 👩‍💻"))
        // Digits carry the Emoji property but not emoji presentation.
        assertEquals("" to "1:1 with Ana", EventLayout.extractEmoji("1:1 with Ana"))
    }

    @Test
    fun `grapheme count matches Swift String count`() {
        assertEquals(3, EventLayout.graphemeCount("a👩‍💻b"))
        assertEquals(2, EventLayout.graphemeCount("☎️x"))
    }

    @Test
    fun `attendee names follow EKParticipant displayName`() {
        assertEquals("Priya", attendeeDisplayName("Priya Raman", "priya@example.com"))
        assertEquals("sam", attendeeDisplayName(null, "sam@example.com"))
        assertEquals("No Name", attendeeDisplayName("", null))
    }
}
