package com.artifact.chronograph.core

/**
 * Port of apple/Extensions/NoteCleanup.swift — keep the marker lists identical;
 * fixtures/note-vectors.tsv verifies the two implementations agree.
 *
 * Strips the boilerplate that calendar and conferencing systems append to event
 * descriptions, so a widget row shows what a human typed rather than dial-in
 * instructions.
 */

/** Google's "do not edit this section" divider. */
const val CALENDAR_SEPARATOR =
    "-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-"

/** The box-drawing rule Zoom puts above its dial-in block. */
const val ZOOM_SEPARATOR = "──────────"

/**
 * Once one of these appears the rest of the description is boilerplate, so the
 * note is truncated there. Matched case-insensitively.
 */
val noteBlockMarkers = listOf(
    // Gmail turns a message into an event and explains itself at length.
    "This event was created from an email you received in Gmail",
    "This event was created from an email",
    // Google Meet / Calendar
    "Join with Google Meet",
    "Join Google Meet",
    "Google Meet joining info",
    "Please do not edit this section",
    "-::~:~::~", // a truncated CALENDAR_SEPARATOR
    // Zoom
    "Join Zoom Meeting",
    "is inviting you to a scheduled Zoom meeting",
    ZOOM_SEPARATOR,
    // Microsoft Teams
    "Microsoft Teams meeting",
    "Join on your computer",
    "________________________________________",
    // Webex / generic
    "----( Video Call )----",
    "Join by phone",
    "Join meeting now",
)

/**
 * Lines that are pure conferencing chrome. Unlike the markers above these can
 * appear on their own without a following block, so the line is dropped and the
 * rest of the note kept. Matched case-insensitively at the line start.
 */
val noteNoiseLinePrefixes = listOf(
    "meeting id:", "meeting url:", "meeting link:",
    "passcode:", "password:", "pin:", "access code:",
    "one tap mobile", "dial by your location", "or dial:", "dial-in",
    "find your local number", "more phone numbers",
    "learn more about meet at", "learn more at",
    "phone conference id:", "video call:",
)

/**
 * Hosts whose links are plumbing, never a document worth surfacing as an
 * attachment row.
 */
val noteNoiseLinkHosts = listOf(
    "mail.google.com", // "view this email in Gmail"
    "meet.google.com", // surfaced separately as the meeting link
    "zoom.us",
    "teams.microsoft.com",
    "tel.meet",
    "support.google.com",
    "aka.ms",
)

/** Truncates at the earliest boilerplate marker, keeping whole lines. */
fun removeMeetingMetadata(text: String, markers: List<String> = noteBlockMarkers): String {
    var earliest = -1
    for (marker in markers) {
        val at = text.indexOf(marker, ignoreCase = true)
        if (at >= 0 && (earliest < 0 || at < earliest)) earliest = at
    }
    if (earliest < 0) return text

    val head = text.substring(0, earliest)
    val lineBreak = head.lastIndexOf('\n')
    if (lineBreak >= 0) return head.substring(0, lineBreak)
    val paragraph = head.lastIndexOf("<p>", ignoreCase = true)
    if (paragraph >= 0) return head.substring(0, paragraph)
    return head
}

/** Drops lines that are nothing but conferencing chrome or a bare noise link. */
fun stripNoiseLines(text: String): String {
    val kept = text.split("\n").filter { line ->
        val bare = strippedOfMarkup(line.trim()).trim()
        if (bare.isEmpty()) return@filter true // blank lines collapse later

        val lowered = bare.lowercase()
        if (noteNoiseLinePrefixes.any { lowered.startsWith(it) }) return@filter false

        // A line that is only a link to a plumbing host carries no information.
        if (!bare.contains(" ") && noteNoiseLinkHosts.any { lowered.contains(it) }) {
            return@filter false
        }
        true
    }
    return collapseBlankLines(kept.joinToString("\n"))
}

/**
 * The whole pipeline: cut the machine-generated tail, drop chrome lines, and
 * return "" when nothing human is left so callers can skip the row entirely.
 */
fun cleanEventNote(raw: String): String {
    val beforeSeparator = raw.split(CALENDAR_SEPARATOR).first()
    val withoutBlocks = removeMeetingMetadata(beforeSeparator)
    val withoutNoise = stripNoiseLines(withoutBlocks)
    val trimmed = withoutNoise.trim()
    // Left with only punctuation or markup scaffolding? Treat it as empty.
    return if (strippedOfMarkup(trimmed).none { it.isLetterOrDigit() }) "" else trimmed
}

private val markupTag = Regex("<[^>]+>")
private val blankRun = Regex("\n{3,}")

private fun strippedOfMarkup(text: String): String =
    markupTag.replace(text, "").replace("&nbsp;", " ")

private fun collapseBlankLines(text: String): String = blankRun.replace(text, "\n\n")
