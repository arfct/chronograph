package com.artifact.chronograph.widget

import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.CalendarContract
import android.text.SpannableString
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import android.text.style.SuperscriptSpan
import android.util.TypedValue
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity as actionStartActivityIntent
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.getAppWidgetState
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.FontStyle
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider as GlanceColorProvider
import com.artifact.chronograph.MainActivity
import com.artifact.chronograph.R
import com.artifact.chronograph.core.CalendarItem
import com.artifact.chronograph.core.Cmudict
import com.artifact.chronograph.core.RowBuilder
import com.artifact.chronograph.core.RowEntry
import com.artifact.chronograph.core.RowMetrics
import com.artifact.chronograph.core.WidgetConfig
import com.artifact.chronograph.core.WidgetFeature
import com.artifact.chronograph.data.CalendarRepository
import com.artifact.chronograph.data.Dictionaries
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Calendar widget — same TimelineEngine shape as iOS: fetch items, build rows
 * in :core, mark conflicts, render. The rendering mirrors ChronographRow.swift
 * closely: compact numerals (big hour, small raised minutes), secondary time
 * color, day headers as DAY-NAME + accent day number, time bars in a
 * fontSize-wide slot, the free-time squiggle, conflict and non-default-calendar
 * indicators, and the iOS visibility pipeline (ended rows dropped, trailing
 * orphaned headers trimmed).
 */
class CalendarWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = getAppWidgetState(context, PreferencesGlanceStateDefinition, id)
        val config = WidgetPrefs.calendarConfig(prefs)
        val transparent = WidgetPrefs.isTransparent(prefs)
        val dictionary = Dictionaries.cmudict(context)
        val rows = buildRows(context, config)
        provideContent {
            GlanceTheme {
                CalendarContent(rows, config, transparent, dictionary)
            }
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent {
            GlanceTheme {
                CalendarContent(
                    sampleRows(), WidgetConfig.calendar,
                    transparent = false, dictionary = null, previewHeight = 212f,
                )
            }
        }
    }

    private fun buildRows(context: Context, config: WidgetConfig): List<RowEntry> {
        if (!CalendarRepository.hasPermission(context)) {
            return listOf(RowEntry(type = "error", title = "Enable access to calendar in settings"))
        }
        val now = Instant.now()
        val rows = RowBuilder.calendarRows(config, CalendarRepository.queryItems(context, now), now)
        RowBuilder.markConflicts(rows)
        return rows.ifEmpty { listOf(RowEntry(type = "empty", title = "No upcoming events")) }
    }

    private fun sampleRows(): List<RowEntry> {
        val now = Instant.now()
        fun item(id: String, title: String, inMinutes: Long) = CalendarItem(
            id = id, title = title,
            start = now.plusSeconds(inMinutes * 60),
            end = now.plusSeconds((inMinutes + 45) * 60),
            calendarId = "sample", calendarTitle = "Work",
        )
        return RowBuilder.calendarRows(
            WidgetConfig.calendar,
            listOf(
                item("1", "Team standup", 30),
                item("2", "Design review", 120),
                item("3", "Focus block", 240),
            ),
            now,
        )
    }
}

@Composable
private fun CalendarContent(
    rows: List<RowEntry>,
    config: WidgetConfig,
    transparent: Boolean,
    dictionary: Cmudict?,
    previewHeight: Float? = null,
) {
    val size = LocalSize.current
    val height = previewHeight ?: size.height.value
    val widthIsLimited = previewHeight == null && size.width.value < 200f
    val heightIsLimited = previewHeight == null && size.height.value < 130f

    // Transparent widgets go full bleed (iOS fullBleed equivalent).
    val vInset = WidgetInsets.vertical(fullBleed = transparent)
    // Metrics come off the full canvas height, as on iOS, where lineHeight and
    // fontSize are derived in init() from context.displaySize before body()
    // applies any padding. The row-packing loop below then spends the *inset*
    // height, which is Android's own mechanism and stricter than iOS's estimate.
    val metrics = RowMetrics.forWidget(config.fontSize, height, compactTime = true)
    val hInset = WidgetInsets.horizontal(fullBleed = transparent, fontSize = metrics.fontSize)
    val now = Instant.now()
    val showTimeBars = WidgetFeature.TIME_BARS in config.features && !widthIsLimited
    val palette = rowPalette(transparent)
    val accent = accentColor(config.accentColor)
    val style = RowStyle(
        metrics = metrics,
        palette = palette,
        accent = GlanceColorProvider(accent),
        barAccent = GlanceColorProvider(accent.copy(alpha = 0.5f)),
        showTimeBars = showTimeBars,
        widthIsLimited = widthIsLimited,
        heightIsLimited = heightIsLimited,
        config = config,
        dictionary = dictionary,
        contentWidth = (previewHeight?.let { 320f } ?: size.width.value) - hInset * 2f -
            metrics.keyline - metrics.columnSpacing * 2f -
            (if (showTimeBars) metrics.fontSize + metrics.columnSpacing else 0f),
    )

    val visible = visibleRows(rows, now, metrics, heightBudget = height - vInset * 2f, style)

    // Explicit transparent color, never an omitted modifier — see TimeZonesWidget.
    val modifier = GlanceModifier
        .fillMaxSize()
        .padding(horizontal = hInset.dp, vertical = vInset.dp)
        .clickable(actionStartActivity<MainActivity>())
        .background(if (transparent) transparentColor else GlanceTheme.colors.widgetBackground)

    Column(modifier = modifier) {
        for (row in visible) {
            when (row.type) {
                "header" -> HeaderRow(row, style)
                "error", "empty" -> MessageRow(row, style)
                "free" -> FreeTimeRow(row, style)
                else -> EventRow(row, style, now)
            }
        }
    }
}

/** Everything EventRowView reads off RowViewConfig, resolved once per render. */
private data class RowStyle(
    val metrics: RowMetrics,
    val palette: RowPalette,
    val accent: GlanceColorProvider,
    val barAccent: GlanceColorProvider,
    val showTimeBars: Boolean,
    val widthIsLimited: Boolean,
    val heightIsLimited: Boolean,
    val config: WidgetConfig,
    val dictionary: Cmudict?,
    /** Width available to the title/detail column, for wrap estimation. */
    val contentWidth: Float,
) {
    val smallSize: Float get() = metrics.smallFontSize
    fun transform(text: String): String = config.obfuscation.transform(text, dictionary)
}

/**
 * iOS renders `.weight(.semibold)` for every piece of small text. Glance exposes
 * only Normal/Medium/Bold, and 600 sits exactly between Medium and Bold; Medium
 * is the closer match at 0.66× body size, where Bold reads as emphasis.
 */
private val SMALL_TEXT_WEIGHT = FontWeight.Medium

/** iOS accentColor: hex when configured, theme secondary otherwise. */
@Composable
private fun accentColor(hex: String): Color {
    val parsed = runCatching { android.graphics.Color.parseColor(hex) }.getOrNull()
    return parsed?.let { Color(it) }
        ?: GlanceTheme.colors.secondary.getColor(LocalContext.current)
}

/**
 * The iOS pipeline: `items.filter { $0.isVisible() }`, clip to the height
 * budget (headers are taller than events), then trim trailing orphaned
 * headers so a day header never dangles at the bottom.
 */
private fun visibleRows(
    rows: List<RowEntry>,
    now: Instant,
    metrics: RowMetrics,
    heightBudget: Float,
    style: RowStyle,
): List<RowEntry> {
    val result = mutableListOf<RowEntry>()
    var used = 0f
    for (row in rows) {
        if (row.hasEnded(now)) continue
        val cost = when (row.type) {
            "header" -> headerHeight(style)
            "error", "empty" -> metrics.lineHeight * 1.5f
            else -> eventHeight(row, now, style)
        }
        if (used + cost > heightBudget && result.isNotEmpty()) break
        used += cost
        result.add(row)
    }
    while (result.isNotEmpty() && result.last().removeIfOrphaned) {
        result.removeAt(result.size - 1)
    }
    return result
}

private fun rowShowsDetails(row: RowEntry, now: Instant, style: RowStyle): Boolean {
    if (style.heightIsLimited || row.item == null) return false
    val soon = row.startAt?.let { it.epochSecond - now.epochSecond < 2 * 3600 } ?: false
    return (row.isHappening(now) || soon) &&
        (!row.locations.isNullOrEmpty() || row.meetingUrl != null ||
            !row.attachments.isNullOrEmpty() || !row.notes.isNullOrBlank())
}

// MARK: heights
//
// EventRowView is intrinsically sized on iOS: the title is `minHeight:
// lineHeight`, each detail line `minHeight: smallLineHeight`, and the detail
// block carries `.padding(.bottom, smallLineHeight/3)`. Glance has no intrinsic
// height for a Row that contains a fillMaxHeight child, so the same sum is
// computed here and used both to lay the row out and to spend the height budget.

/** HeaderRowView: lineHeight of content plus its top/bottom padding. */
private fun headerHeight(style: RowStyle): Float {
    val m = style.metrics
    val large = style.showTimeBars && !style.widthIsLimited && !style.heightIsLimited
    // large: .padding(.top, lineHeight/4) outside, .padding(.vertical, lineHeight/4) inside
    if (large) return m.lineHeight + m.lineHeight / 4f + m.lineHeight / 2f
    if (style.heightIsLimited) return m.lineHeight
    return m.lineHeight + m.lineHeight / 2f + m.lineHeight / 8f
}

private fun eventHeight(row: RowEntry, now: Instant, style: RowStyle): Float {
    val m = style.metrics
    if (!rowShowsDetails(row, now, style)) return m.lineHeight
    return m.lineHeight + detailLines(row, style) * m.smallLineHeight + m.smallLineHeight / 3f
}

/**
 * How many small lines the detail block will occupy. Notes are the only variable
 * one: iOS lets `lineLimit(2)` grow to fit, so the wrap is estimated from the
 * column width rather than clipped — 0.55 em is a reasonable mean advance for
 * Roboto at these sizes, and over-estimating costs whitespace while
 * under-estimating truncates a note mid-sentence.
 */
private fun detailLines(row: RowEntry, style: RowStyle): Int {
    var lines = 0
    if (row.meetingUrl != null || !row.locations.isNullOrEmpty()) lines++
    lines += (row.attachments?.size ?: 0).coerceAtMost(MAX_ATTACHMENT_ROWS)
    row.notes?.takeIf { it.isNotBlank() }?.let { notes ->
        val perLine = (style.contentWidth / (style.smallSize * 0.55f)).toInt().coerceAtLeast(8)
        lines += if (notes.length > perLine) 2 else 1
    }
    return lines
}

// MARK: compact numerals — TimeStringView with compactTime (the iOS default):
// monospaced-feel big hour, small semibold minutes top-aligned to read raised.

private val hourFormat = DateTimeFormatter.ofPattern("h", Locale.US)
private val minuteFormat = DateTimeFormatter.ofPattern("mm", Locale.US)

/**
 * iOS lifts the minutes with `.baselineOffset(fontSize * 0.24)` so they read as a
 * superscript. Glance cannot express that: `Text` takes a String, so no spans,
 * and a Row's `verticalAlignment` is not a substitute — Top and Bottom both
 * render the smaller run sitting on the shared baseline, i.e. as a subscript,
 * which is the opposite of the intent. Padding underneath does not move it
 * either. So the time is a real TextView carrying the same span pair that gives
 * the Time Zones rows their raised meridiem.
 */
@Composable
private fun CompactTime(instant: Instant, style: RowStyle, color: GlanceColorProvider) {
    val context = LocalContext.current
    val zoned = instant.atZone(ZoneId.systemDefault())
    val hour = hourFormat.format(zoned)
    val minute = minuteFormat.format(zoned)
    val text = SpannableString(hour + minute).apply {
        setSpan(
            RelativeSizeSpan(RowMetrics.SMALL_TEXT_SCALE),
            hour.length, length, Spanned.SPAN_INCLUSIVE_INCLUSIVE,
        )
        setSpan(SuperscriptSpan(), hour.length, length, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
    }
    AndroidRemoteViews(
        remoteViews = RemoteViews(context.packageName, R.layout.row_time).apply {
            setCharSequence(R.id.row_time, "setText", text)
            setTextViewTextSize(R.id.row_time, TypedValue.COMPLEX_UNIT_SP, style.metrics.fontSize)
            setTextColor(R.id.row_time, color.getColor(context).toArgb())
        },
        modifier = GlanceModifier.fillMaxWidth(),
    )
}

/** iOS TimeBarView inside its fontSize-wide slot. */
@Composable
private fun TimeBarSlot(style: RowStyle, color: GlanceColorProvider?) {
    Column(
        modifier = GlanceModifier
            .width(style.metrics.fontSize.dp)
            .fillMaxHeight()
            .padding(vertical = (style.metrics.fontSize / 12f).dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (color != null) {
            Box(
                modifier = GlanceModifier
                    .width((0.085f * style.metrics.fontSize * 1.5f).dp)
                    .fillMaxHeight()
                    .cornerRadius(2.dp)
                    .background(color),
            ) {}
        }
    }
}

/** FreeRowView's "Time Squiggle" slot: a wavy vertical glyph at 2/3 opacity. */
@Composable
private fun SquiggleSlot(style: RowStyle) {
    Column(
        modifier = GlanceModifier.width(style.metrics.fontSize.dp).fillMaxHeight(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "⌇",
            style = TextStyle(color = style.palette.secondary, fontSize = style.smallSize.sp),
        )
    }
}

// MARK: rows

private val dayNameFormat = DateTimeFormatter.ofPattern("EEE", Locale.getDefault())
private val dayNumberFormat = DateTimeFormatter.ofPattern("d", Locale.getDefault())

/**
 * HeaderRowView: DAY-NAME small caps in the keyline, day number in accent,
 * all-day titles in small secondary. The large variant (big widgets with time
 * bars) shows a light 1.8× day number aligned with the bars column.
 */
@Composable
private fun HeaderRow(row: RowEntry, style: RowStyle) {
    val m = style.metrics
    val startAt = row.startAt ?: return
    val zoned = startAt.atZone(ZoneId.systemDefault())
    val dayName = style.transform(dayNameFormat.format(zoned)).uppercase()
    val dayNumber = dayNumberFormat.format(zoned)
    val allDayTitles = row.allDayItems.orEmpty().take(if (style.widthIsLimited) 2 else 3)
        .mapNotNull { it.item?.title }
    val large = style.showTimeBars && !style.widthIsLimited && !style.heightIsLimited

    var modifier = GlanceModifier.fillMaxWidth()
    row.startAt?.let { dayIntent(row)?.let { intent -> modifier = modifier.clickable(actionStartActivityIntent(intent)) } }

    val cs = m.columnSpacing
    // iOS kerns the day name by 1pt; Glance TextStyle has no letter spacing, so
    // that one detail cannot be reproduced.
    val dayNameStyle = TextStyle(
        color = style.palette.primary,
        fontSize = style.smallSize.sp,
        fontWeight = SMALL_TEXT_WEIGHT,
    )

    if (large) {
        Row(
            // Explicit height: an unbounded row lets the bar slot's
            // fillMaxHeight consume the whole widget.
            modifier = modifier.height(headerHeight(style).dp).padding(top = (m.lineHeight / 4).dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(modifier = GlanceModifier.width(m.keyline.dp), contentAlignment = Alignment.CenterEnd) {
                // iOS draws this at .weight(.light); Glance offers no light weight.
                Text(
                    text = dayNumber,
                    style = TextStyle(color = style.accent, fontSize = (m.fontSize * 1.8f).sp),
                    maxLines = 1,
                )
            }
            Box(modifier = GlanceModifier.padding(start = cs.dp).fillMaxHeight()) {
                TimeBarSlot(style, style.barAccent)
            }
            Column(
                modifier = GlanceModifier.defaultWeight()
                    .padding(start = cs.dp, top = (m.lineHeight / 4).dp, bottom = (m.lineHeight / 4).dp),
            ) {
                Text(text = dayName, style = dayNameStyle, maxLines = 1)
                if (allDayTitles.isNotEmpty()) {
                    Text(
                        text = style.transform(allDayTitles.joinToString("  ")),
                        style = TextStyle(
                            color = style.palette.secondary,
                            fontSize = style.smallSize.sp,
                            fontWeight = SMALL_TEXT_WEIGHT,
                        ),
                        maxLines = 1,
                    )
                }
            }
        }
    } else {
        Row(
            modifier = modifier.padding(
                top = (if (style.heightIsLimited) 0f else m.lineHeight / 2).dp,
                bottom = (if (style.heightIsLimited) 0f else m.lineHeight / 8).dp,
            ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(modifier = GlanceModifier.width(m.keyline.dp), contentAlignment = Alignment.CenterEnd) {
                Text(text = dayName, style = dayNameStyle, maxLines = 1)
            }
            if (!style.widthIsLimited) {
                Box(
                    modifier = GlanceModifier.padding(start = cs.dp).width(m.fontSize.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = dayNumber,
                        style = TextStyle(color = style.accent, fontSize = style.smallSize.sp),
                        maxLines = 1,
                    )
                }
            }
            if (allDayTitles.isNotEmpty()) {
                Text(
                    text = style.transform(allDayTitles.joinToString("  ")),
                    style = TextStyle(
                        color = style.palette.secondary,
                        fontSize = style.smallSize.sp,
                        fontWeight = SMALL_TEXT_WEIGHT,
                    ),
                    maxLines = 1,
                    modifier = GlanceModifier.padding(start = cs.dp).defaultWeight(),
                )
            }
        }
    }
}

@Composable
private fun EventRow(row: RowEntry, style: RowStyle, now: Instant) {
    val m = style.metrics
    val isHappening = row.isHappening(now)
    val soon = row.startAt?.let { it.epochSecond - now.epochSecond < 2 * 3600 } ?: false
    val showDetails = rowShowsDetails(row, now, style)
    val twoLines = !style.heightIsLimited && (isHappening || soon)

    val cs = m.columnSpacing
    var rowModifier = GlanceModifier.fillMaxWidth().height(eventHeight(row, now, style).dp)
    eventIntent(row)?.let { rowModifier = rowModifier.clickable(actionStartActivityIntent(it)) }

    // iOS uses HStack(alignment: .top): with a detail block the time stays level
    // with the title instead of drifting to the middle of the row.
    Row(modifier = rowModifier, verticalAlignment = Alignment.Top) {
        Box(
            // Height is one line, not the whole row, so .Top plus centring
            // inside the line reproduces the SwiftUI frame(minHeight: lineHeight).
            modifier = GlanceModifier.width(m.keyline.dp).height(m.lineHeight.dp),
            contentAlignment = Alignment.CenterEnd,
        ) {
            // Same-start conflicts leave the keyline empty, like EventRowView.
            if (!(row.hasConflict && row.hasStartConflict)) {
                row.startAt?.let { CompactTime(it, style, style.palette.secondary) }
            }
        }
        // The bar column exists on iOS even when bars are off — it is `Text("")`,
        // zero-width but still spaced — so the gap is 2× columnSpacing either way.
        if (style.showTimeBars) {
            Box(modifier = GlanceModifier.padding(start = cs.dp).fillMaxHeight()) {
                TimeBarSlot(style, style.barAccent)
            }
        }

        Column(modifier = GlanceModifier.defaultWeight().padding(start = (if (style.showTimeBars) cs else cs * 2f).dp)) {
            Row(
                modifier = GlanceModifier.height(m.lineHeight.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = style.transform(row.item?.title ?: row.title ?: "Untitled"),
                    style = TextStyle(
                        color = style.palette.primary,
                        fontSize = m.fontSize.sp,
                        fontWeight = if (isHappening) FontWeight.Medium else FontWeight.Normal,
                    ),
                    maxLines = if (twoLines) 2 else 1,
                )
                // iOS spaces this HStack by 2pt rather than padding the glyphs.
                if (row.hasConflict && !style.widthIsLimited) {
                    Text(
                        text = "⚠︎",
                        style = TextStyle(color = style.palette.secondary, fontSize = style.smallSize.sp),
                        modifier = GlanceModifier.padding(start = 2.dp),
                    )
                }
                if (row.item?.isDefaultCalendar == false) {
                    Text(
                        text = circledInitial(row.item?.calendarTitle),
                        style = TextStyle(color = style.accent, fontSize = m.fontSize.sp),
                        modifier = GlanceModifier.padding(start = 2.dp),
                    )
                }
            }
            if (showDetails) {
                // .padding(.bottom, smallLineHeight/3) on the detail block.
                Column(modifier = GlanceModifier.padding(bottom = (m.smallLineHeight / 3f).dp)) {
                    if (row.meetingUrl != null || !row.locations.isNullOrEmpty()) {
                        Row(
                            modifier = GlanceModifier.height(m.smallLineHeight.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            row.meetingUrl?.let { url ->
                                Text(
                                    text = "📹 " + style.transform(row.meetingTitle ?: "Video conference"),
                                    style = TextStyle(
                                        color = style.palette.primary,
                                        fontSize = style.smallSize.sp,
                                        fontWeight = SMALL_TEXT_WEIGHT,
                                    ),
                                    maxLines = 1,
                                    modifier = GlanceModifier.clickable(
                                        actionStartActivityIntent(Intent(Intent.ACTION_VIEW, Uri.parse(url))),
                                    ),
                                )
                            }
                            row.locations?.takeIf { it.isNotEmpty() }?.let { locations ->
                                Text(
                                    text = style.transform(locations.joinToString(", ")),
                                    style = TextStyle(
                                        color = style.palette.secondary,
                                        fontSize = style.smallSize.sp,
                                        fontWeight = SMALL_TEXT_WEIGHT,
                                        fontStyle = FontStyle.Italic,
                                    ),
                                    maxLines = 1,
                                    // SwiftUI's default HStack spacing.
                                    modifier = if (row.meetingUrl != null) {
                                        GlanceModifier.padding(start = 8.dp)
                                    } else {
                                        GlanceModifier
                                    },
                                )
                            }
                        }
                    }
                    // Document links lifted out of the description, one row each.
                    row.attachments?.take(MAX_ATTACHMENT_ROWS)?.forEach { doc ->
                        Text(
                            text = attachmentGlyph(doc.displayIcon) + " " +
                                (doc.prefix?.takeIf { it.isNotBlank() }?.let { "$it " } ?: "") +
                                style.transform(doc.displayName),
                            style = TextStyle(
                                color = style.palette.primary,
                                fontSize = style.smallSize.sp,
                                fontWeight = SMALL_TEXT_WEIGHT,
                            ),
                            maxLines = 1,
                            modifier = GlanceModifier
                                .height(m.smallLineHeight.dp)
                                .clickable(
                                    actionStartActivityIntent(Intent(Intent.ACTION_VIEW, Uri.parse(doc.urlString))),
                                ),
                        )
                    }
                    // Whatever a human actually wrote, boilerplate already stripped.
                    row.notes?.takeIf { it.isNotBlank() }?.let { notes ->
                        val noteLines = if (notes.length >
                            (style.contentWidth / (style.smallSize * 0.55f)).toInt().coerceAtLeast(8)
                        ) 2 else 1
                        Text(
                            text = style.transform(notes),
                            style = TextStyle(
                                color = style.palette.secondary,
                                fontSize = style.smallSize.sp,
                                fontWeight = SMALL_TEXT_WEIGHT,
                            ),
                            maxLines = noteLines,
                            modifier = GlanceModifier.height((m.smallLineHeight * noteLines).dp),
                        )
                    }
                }
            }
        }
    }
}

/** Apple renders SF Symbols here; the glyphs are the closest text analogue. */
private const val MAX_ATTACHMENT_ROWS = 2

private fun attachmentGlyph(icon: String): String = when (icon) {
    "document" -> "📄"
    "bubble" -> "💬"
    else -> "🔗"
}

/** iOS `<initial>.circle` indicator for events off the default calendar. */
private fun circledInitial(calendarTitle: String?): String {
    val letter = calendarTitle?.firstOrNull()?.lowercaseChar() ?: return "◦"
    return if (letter in 'a'..'z') ('ⓐ' + (letter - 'a')).toString() else "◦"
}

@Composable
private fun FreeTimeRow(row: RowEntry, style: RowStyle) {
    val m = style.metrics
    Row(
        modifier = GlanceModifier.fillMaxWidth().height(m.lineHeight.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = GlanceModifier.width(m.keyline.dp)) {}
        // FreeRowView omits the empty bar column that EventRowView keeps, so the
        // gap here is a single columnSpacing rather than two.
        if (style.showTimeBars) {
            Box(modifier = GlanceModifier.padding(start = m.columnSpacing.dp).fillMaxHeight()) {
                SquiggleSlot(style)
            }
        }
        Text(
            text = style.transform(row.title ?: "Free"),
            style = TextStyle(
                color = style.palette.secondary,
                fontSize = style.smallSize.sp,
                fontWeight = SMALL_TEXT_WEIGHT,
                fontStyle = FontStyle.Italic,
            ),
            maxLines = 1,
            modifier = GlanceModifier.padding(start = m.columnSpacing.dp),
        )
    }
}

@Composable
private fun MessageRow(row: RowEntry, style: RowStyle) {
    Box(
        modifier = GlanceModifier.fillMaxWidth().height((style.metrics.lineHeight * 1.5f).dp),
        contentAlignment = Alignment.BottomStart,
    ) {
        Text(
            text = row.title ?: "",
            style = TextStyle(color = style.palette.secondary, fontSize = style.metrics.fontSize.sp),
        )
    }
}

/** Counterpart of EventRowView's Link: open the event in the calendar app. */
private fun eventIntent(row: RowEntry): Intent? {
    val eventId = row.item?.id?.toLongOrNull() ?: return null
    return Intent(Intent.ACTION_VIEW)
        .setData(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId))
        .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, row.startAt?.toEpochMilli() ?: 0L)
        .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, row.endAt?.toEpochMilli() ?: 0L)
}

/** Day headers open the calendar at that day. */
private fun dayIntent(row: RowEntry): Intent? {
    val millis = row.startAt?.toEpochMilli() ?: return null
    return Intent(
        Intent.ACTION_VIEW,
        CalendarContract.CONTENT_URI.buildUpon()
            .appendPath("time")
            .appendPath(millis.toString())
            .build(),
    )
}

class CalendarWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CalendarWidget()
}
