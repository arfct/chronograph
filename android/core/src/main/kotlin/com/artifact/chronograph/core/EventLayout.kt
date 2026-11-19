package com.artifact.chronograph.core

import java.text.BreakIterator
import java.time.Instant

/**
 * The event-row half of ChronographWidget.swift's row packing (`rowHeight`,
 * `titleWraps`, `detailsVisible`, `detailHeight`) plus the EventRowView gates
 * it mirrors. iOS sizes rows intrinsically and estimates the same sum to decide
 * how many fit; Glance cannot measure, so Android lays each row out at exactly
 * this height and packs with it too. Keeping both in one place is what stops a
 * title or note from being given less room than it draws in.
 *
 * `column` is the width left for the title and detail block once the keyline,
 * time bar and column spacing are taken.
 */
object EventLayout {

    /** Mean advance as a fraction of the font size; see [charactersPerLine]. */
    const val MEAN_ADVANCE_EM = 0.55f

    /**
     * `charactersPerLine`: a mean advance of 0.55 em, generous for SF and
     * Roboto alike, so a wrap is over- rather than under-predicted.
     * Over-predicting costs a line of whitespace; under-predicting is what
     * clipped titles through the middle of their second line.
     */
    fun charactersPerLine(column: Float, fontSize: Float): Int =
        maxOf(8, (column / (fontSize * MEAN_ADVANCE_EM)).toInt())

    /** `isHappening || isSoon` and room to show it — EventRowView's gate for both
     *  the two-line title and the detail block. */
    fun isExpanded(row: RowEntry, now: Instant, heightIsLimited: Boolean): Boolean =
        !heightIsLimited && (row.isHappening(now) || row.isSoon(now))

    /** EventRowView's `lineLimit(2)` on the title, as `titleWraps` estimates it. */
    fun titleWraps(title: String?, column: Float, metrics: RowMetrics, expanded: Boolean): Boolean {
        if (!expanded || title.isNullOrEmpty()) return false
        return graphemeCount(title) > charactersPerLine(column, metrics.fontSize)
    }

    /** One line, or two unspread text lines — `max(line, 2 * textLine)`. */
    fun titleHeight(metrics: RowMetrics, wraps: Boolean): Float =
        if (wraps) maxOf(metrics.lineHeight, 2f * metrics.lineHeight / RowMetrics.LINE_SPREAD)
        else metrics.lineHeight

    /** `detailsVisible`: details exist and the row is happening or soon. */
    fun detailsVisible(row: RowEntry, expanded: Boolean): Boolean =
        expanded && row.item != null && (row.hasAttachments || row.hasLocation || row.hasNotes)

    /** A note takes its second line (`lineLimit(2)`) on a newline or by length. */
    fun noteWraps(notes: String, column: Float, metrics: RowMetrics): Boolean =
        notes.contains('\n') ||
            graphemeCount(notes) > charactersPerLine(column, metrics.smallFontSize)

    fun noteHeight(metrics: RowMetrics, wraps: Boolean): Float {
        val small = metrics.smallLineHeight
        return if (wraps) maxOf(small, 2f * small / RowMetrics.LINE_SPREAD) else small
    }

    /**
     * The detail block, without its bottom padding: the location line (which
     * carries the meeting link), one line per attachment, the attendee line,
     * then the note.
     *
     * iOS counts an attendee line for any event with attendees even though
     * FacePile draws nothing below three; Android counts it only when drawn.
     */
    fun detailHeight(row: RowEntry, column: Float, metrics: RowMetrics): Float {
        var lines = 0
        if (row.hasLocation) lines += 1
        lines += row.attachments?.size ?: 0
        if (row.showsAttendees) lines += 1
        var height = lines * metrics.smallLineHeight
        if (row.hasNotes) height += noteHeight(metrics, noteWraps(row.notes!!, column, metrics))
        return height
    }

    /** `rowHeight` for an event: title, then details plus `smallLineHeight / 3`. */
    fun eventHeight(row: RowEntry, now: Instant, column: Float, metrics: RowMetrics, heightIsLimited: Boolean): Float {
        val expanded = isExpanded(row, now, heightIsLimited)
        val height = titleHeight(metrics, titleWraps(row.item?.title, column, metrics, expanded))
        if (!detailsVisible(row, expanded)) return height
        return height + detailHeight(row, column, metrics) + metrics.smallLineHeight / 3f
    }

    /**
     * Port of `extractEmoji(from:)`: EventRowView pulls emoji-presentation
     * characters out of a title and draws them after it at the small size.
     * Returns (emoji, remaining title).
     */
    fun extractEmoji(input: String): Pair<String, String> {
        val emoji = StringBuilder()
        val remaining = StringBuilder()
        forEachGrapheme(input) { cluster ->
            val isEmoji = cluster.codePoints().anyMatch {
                Character.isEmojiPresentation(it) && !Character.isDigit(it)
            }
            (if (isEmoji) emoji else remaining).append(cluster)
        }
        return emoji.toString() to remaining.toString().trim()
    }

    /** Swift's `String.count`: extended grapheme clusters, not UTF-16 units. */
    fun graphemeCount(text: String): Int {
        var count = 0
        forEachGrapheme(text) { count++ }
        return count
    }

    private inline fun forEachGrapheme(text: String, action: (String) -> Unit) {
        val it = BreakIterator.getCharacterInstance()
        it.setText(text)
        var start = it.first()
        var end = it.next()
        while (end != BreakIterator.DONE) {
            action(text.substring(start, end))
            start = end
            end = it.next()
        }
    }
}

/** EKParticipant.displayName: first word of the name, else the email's local part. */
fun attendeeDisplayName(name: String?, email: String?): String {
    if (!name.isNullOrEmpty()) {
        return name.split(' ', '@').firstOrNull() ?: name
    }
    val local = email?.takeIf { it.isNotEmpty() }?.substringBefore('@')
    return local?.takeIf { it.isNotEmpty() } ?: "No Name"
}
