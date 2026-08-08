package com.artifact.chronograph.core

/**
 * Port of the note-parsing half of apple/Extensions/StringProcessing.swift and
 * EventEntries.swift's EventAttachment.
 *
 * `extractMeetingUrls` is fixture-verified against Swift. `stripHtmlTags` is
 * not: Apple routes it through NSAttributedString's HTML parser, whose
 * whitespace and entity handling isn't reasonably reproducible here, so this is
 * a pragmatic tag-strip plus the entities that actually show up in calendar
 * descriptions. Attachment prefixes are covered by Kotlin-side tests instead.
 */

/** Port of EventAttachment. */
data class EventAttachment(
    val urlString: String,
    val title: String? = null,
    val prefix: String? = null,
) {
    /** Host, when the URL is well-formed enough to have one. */
    val type: String? get() = hostOf(urlString)

    val displayName: String
        get() = title?.takeIf { it.isNotBlank() && !it.startsWith("https") }
            ?: titleFromUrl(urlString)
            ?: hostOf(urlString)
            ?: urlString

    /** Matches Apple's typeImageMappings, resolved to drawable names. */
    val displayIcon: String
        get() = when (type) {
            "paper.dropbox.com", "docs.google.com" -> "document"
            "slack.com" -> "bubble"
            else -> "link"
        }
}

private val hostPattern = Regex("""^[a-z][a-z0-9+.\-]*://([^/?#\s]+)""", RegexOption.IGNORE_CASE)

internal fun hostOf(url: String): String? =
    hostPattern.find(url)?.groupValues?.get(1)?.lowercase()

private val dropboxPaperTitle = Regex("""https://paper\.dropbox\.com/doc/([^\-]+)--""")

/** Port of extractTitleFromURL. */
fun titleFromUrl(url: String): String? {
    dropboxPaperTitle.find(url)?.let { return it.groupValues[1].replace("-", " ") }
    if (url.contains("zoom.us")) return "Zoom"
    if (url.contains("meet.google.com")) return "Meet"
    return hostOf(url)
}

private val meetingPatterns = listOf(
    Regex("""https://(?:\w+\.)?zoom\.us/j/\d+\?pwd=\w+"""),
    Regex("""https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"""),
    Regex("""https://facetime\.apple\.com/join#[^\s">]+"""),
)

/** Port of extractMeetingUrls — same patterns, same order. */
fun extractMeetingUrls(text: String): List<EventAttachment> =
    meetingPatterns.flatMap { pattern ->
        pattern.findAll(text).map { EventAttachment(urlString = it.value) }
    }

private val anchorPattern = Regex(
    """(.*?)(<a\s+href="(https?://[^"]+)"[^>]*>([^<]+)</a>)""",
    RegexOption.IGNORE_CASE,
)
private val barePattern = Regex("""([^>]*?)(https?://[^\s"<]+)""", RegexOption.IGNORE_CASE)

/**
 * Port of extractAttachments: anchors first, then bare URLs, de-duplicated by
 * URL. Returns the attachments and the text with those matches removed.
 */
fun extractAttachments(html: String): Pair<List<EventAttachment>, String> {
    val seen = LinkedHashSet<String>()
    val results = mutableListOf<EventAttachment>()
    val ranges = mutableListOf<IntRange>()

    for (m in anchorPattern.findAll(html)) {
        val url = m.groupValues[3]
        if (!seen.add(url)) continue
        results += EventAttachment(
            urlString = url,
            title = m.groupValues[4],
            prefix = cleanPrefix(m.groupValues[1]),
        )
        ranges += m.range
    }

    for (m in barePattern.findAll(html)) {
        val url = m.groupValues[2]
        if (!seen.add(url)) continue
        results += EventAttachment(urlString = url, prefix = cleanPrefix(m.groupValues[1]))
        ranges += m.range
    }

    var cleaned = html
    for (r in ranges.sortedByDescending { it.first }) {
        if (r.first <= cleaned.length && r.last < cleaned.length) {
            cleaned = cleaned.removeRange(r)
        }
    }
    return results to cleaned
}

private val entities = mapOf(
    "&nbsp;" to " ", "&amp;" to "&", "&lt;" to "<", "&gt;" to ">",
    "&quot;" to "\"", "&#39;" to "'", "&apos;" to "'", "&mdash;" to "—",
    "&ndash;" to "–", "&hellip;" to "…",
)

/** Pragmatic stand-in for Apple's NSAttributedString HTML strip. */
fun stripHtmlTags(html: String): String {
    var text = Regex("<br\\s*/?>", RegexOption.IGNORE_CASE).replace(html, "\n")
    text = Regex("</p>", RegexOption.IGNORE_CASE).replace(text, "\n")
    text = Regex("<[^>]+>").replace(text, "")
    for ((entity, plain) in entities) text = text.replace(entity, plain, ignoreCase = true)
    return text
}

/** Port of cleanPrefix. */
fun cleanPrefix(prefix: String): String =
    stripHtmlTags(prefix).trim { it.isWhitespace() || it == '-' || it == '•' }
