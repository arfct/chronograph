package com.artifact.chronograph.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.TestFactory
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.util.Locale

/**
 * Golden-vector parity with the Swift note cleanup. The fixtures are generated
 * FROM apple/Extensions/NoteCleanup.swift (the source of truth) by
 * scripts/generate-note-vectors.swift; if this fails, fix the Kotlin port —
 * never the vectors by hand.
 */
class NoteVectorsTest {

    private fun unescape(s: String) = s
        .replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace("\\\\", "\\")

    @TestFactory
    fun `cleanEventNote matches the Swift implementation`(): List<DynamicTest> {
        val lines = File(System.getProperty("chronograph.fixtures"), "note-vectors.tsv")
            .readLines()
            .drop(1) // header

        check(lines.size >= 15) { "suspiciously few vectors: ${lines.size}" }

        return lines.map { line ->
            // A trailing empty column means "cleans to nothing".
            val parts = line.split("\t")
            val raw = unescape(parts[0])
            val expected = unescape(parts.getOrElse(1) { "" })
            DynamicTest.dynamicTest("note: ${raw.take(48).replace("\n", "\\n")}") {
                assertEquals(expected, cleanEventNote(raw))
            }
        }
    }

    // --- Kotlin-side coverage for the parts that can't be fixture-verified ---
    // stripHtmlTags stands in for Apple's NSAttributedString HTML parser, so
    // attachment prefixes and titles are checked here rather than cross-language.

    @Test
    fun `document links survive and conferencing links do not`() {
        val (links, _) = extractAttachments(
            "Plan: https://paper.dropbox.com/doc/Roadmap--xyz and https://meet.google.com/abc-defg-hij"
        )
        val kept = links.filterNot { l -> noteNoiseLinkHosts.any { l.urlString.contains(it) } }
        assertEquals(1, kept.size)
        assertEquals("paper.dropbox.com", kept.first().type)
        assertEquals("document", kept.first().displayIcon)
        assertEquals("Roadmap", kept.first().displayName)
    }

    @Test
    fun `anchor tags yield title and prefix`() {
        val (links, _) = extractAttachments("""- Agenda <a href="https://example.com/a">Q3 plan</a>""")
        assertEquals(1, links.size)
        assertEquals("Q3 plan", links.first().title)
        assertEquals("Agenda", links.first().prefix)
    }

    @Test
    fun `meeting urls are recognised per provider`() {
        assertEquals(
            "https://meet.google.com/abc-defg-hij",
            extractMeetingUrls("Join https://meet.google.com/abc-defg-hij now").first().urlString,
        )
        assertEquals(
            "Zoom",
            extractMeetingUrls("https://acme.zoom.us/j/123456?pwd=abc").first().displayName,
        )
        assertTrue(extractMeetingUrls("no links here").isEmpty())
    }

    @Test
    fun `row builder suppresses boilerplate and keeps the human sentence`() {
        val now = Instant.parse("2026-08-08T17:00:00Z")
        val item = CalendarItem(
            id = "1",
            title = "Sync",
            start = now.plusSeconds(1800),
            end = now.plusSeconds(5400),
            location = "https://meet.google.com/abc-defg-hij",
            description = "Bring metrics.\n\nThis event was created from an email you received in Gmail. " +
                "https://mail.google.com/mail?extsrc=cal&plid=ACUX6DO",
        )
        val entry = RowBuilder
            .calendarRows(WidgetConfig.calendar, listOf(item), now, ZoneId.of("UTC"), Locale.US)
            .first { it.item != null }

        assertEquals("Bring metrics.", entry.notes)
        assertEquals("https://meet.google.com/abc-defg-hij", entry.meetingUrl)
        assertNull(entry.attachments, "the Gmail link must not become an attachment row")
    }
}
