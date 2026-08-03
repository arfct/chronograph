package com.artifact.chronograph.widget

import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.provider.CalendarContract
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity as actionStartActivityIntent
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.getAppWidgetState
import androidx.glance.background
import androidx.glance.color.ColorProvider
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
 * in :core, mark conflicts, render. Per-widget options come from Glance state
 * (WidgetPrefs) exactly like the per-widget AppIntents parameters on iOS.
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
    val height = previewHeight ?: LocalSize.current.height.value
    // Transparent widgets go full bleed — without a surface, the inset reads
    // as misalignment against the launcher grid (iOS fullBleed equivalent).
    val inset = if (transparent) 0 else 12
    // iOS keylines are minWidth and can grow; Glance widths are fixed, so use
    // the wide keyline to fit five-character times like "10:43".
    val metrics = RowMetrics.forWidget(config.fontSize, height - inset * 2f, compactTime = false)
    val now = Instant.now()
    val showTimeBars = WidgetFeature.TIME_BARS in config.features
    val accent = accentColorProvider(config.accentColor)
    val palette = rowPalette(transparent)

    // Explicit transparent color, never an omitted modifier — see TimeZonesWidget.
    val modifier = GlanceModifier
        .fillMaxSize()
        .padding(inset.dp)
        .clickable(actionStartActivity<MainActivity>())
        .background(if (transparent) transparentColor else GlanceTheme.colors.widgetBackground)

    Column(modifier = modifier) {
        for (row in rows.take(maxOf(metrics.visibleRows, 1))) {
            when (row.type) {
                "header" -> HeaderRow(row, metrics, showTimeBars, config, dictionary, palette)
                "error", "empty" -> MessageRow(row, metrics, palette)
                "free" -> FreeTimeRow(row, metrics, showTimeBars, palette)
                else -> EventRow(row, metrics, now, showTimeBars, accent, config, dictionary, palette)
            }
        }
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

/** iOS TimeBarView: thin rounded accent bar at half opacity beside the keyline. */
@Composable
private fun TimeBarSlot(metrics: RowMetrics, color: GlanceColorProvider?) {
    Column(
        modifier = GlanceModifier
            .width((metrics.fontSize * 0.5f).dp)
            .fillMaxHeight()
            .padding(vertical = (metrics.fontSize / 12f).dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (color != null) {
            Box(
                modifier = GlanceModifier
                    .width((0.085f * metrics.fontSize * 1.5f).dp)
                    .fillMaxHeight()
                    .cornerRadius(2.dp)
                    .background(color),
            ) {}
        }
    }
}

@Composable
private fun accentColorProvider(hex: String): GlanceColorProvider {
    val parsed = runCatching { android.graphics.Color.parseColor(hex) }.getOrNull()
    return if (parsed != null) {
        val half = Color(parsed).copy(alpha = 0.5f)
        ColorProvider(half, half)
    } else {
        GlanceTheme.colors.secondary
    }
}

@Composable
private fun HeaderRow(
    row: RowEntry,
    metrics: RowMetrics,
    showTimeBars: Boolean,
    config: WidgetConfig,
    dictionary: Cmudict?,
    palette: RowPalette,
) {
    var rowModifier = GlanceModifier.fillMaxWidth().height(metrics.lineHeight.dp)
    dayIntent(row)?.let { rowModifier = rowModifier.clickable(actionStartActivityIntent(it)) }

    Row(
        modifier = rowModifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = GlanceModifier.width(metrics.keyline.dp)) {}
        if (showTimeBars) TimeBarSlot(metrics, color = null)
        Text(
            text = config.obfuscation.transform(row.title ?: "", dictionary),
            style = TextStyle(
                color = palette.primary,
                fontSize = metrics.fontSize.sp,
                fontWeight = FontWeight.Bold,
            ),
            maxLines = 1,
            modifier = GlanceModifier.padding(start = 8.dp),
        )
        val allDayTitles = row.allDayItems.orEmpty().mapNotNull { it.item?.title }
        if (allDayTitles.isNotEmpty()) {
            Text(
                text = config.obfuscation.transform(allDayTitles.joinToString(", "), dictionary),
                style = TextStyle(
                    color = palette.secondary,
                    fontSize = (metrics.fontSize * RowMetrics.SMALL_TEXT_SCALE).sp,
                ),
                maxLines = 1,
                modifier = GlanceModifier.padding(start = 8.dp).defaultWeight(),
            )
        }
    }
}

@Composable
private fun EventRow(
    row: RowEntry,
    metrics: RowMetrics,
    now: Instant,
    showTimeBars: Boolean,
    accent: GlanceColorProvider,
    config: WidgetConfig,
    dictionary: Cmudict?,
    palette: RowPalette,
) {
    val hasEnded = row.hasEnded(now)
    val isHappening = row.isHappening(now)
    val color = if (hasEnded) palette.secondary else palette.primary

    var rowModifier = GlanceModifier.fillMaxWidth().height(metrics.lineHeight.dp)
    eventIntent(row)?.let { rowModifier = rowModifier.clickable(actionStartActivityIntent(it)) }

    Row(
        modifier = rowModifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = GlanceModifier.width(metrics.keyline.dp),
            contentAlignment = Alignment.CenterEnd,
        ) {
            // Same-start conflicts leave the keyline empty, like EventRowView.
            if (!(row.hasConflict && row.hasStartConflict)) {
                Text(
                    text = row.startAt?.let(::shortTime) ?: "",
                    style = TextStyle(color = color, fontSize = metrics.fontSize.sp),
                    maxLines = 1,
                )
            }
        }
        if (showTimeBars) TimeBarSlot(metrics, color = accent)
        Text(
            text = config.obfuscation.transform(row.item?.title ?: row.title ?: "Event", dictionary),
            style = TextStyle(
                color = color,
                fontSize = metrics.fontSize.sp,
                fontWeight = if (isHappening) FontWeight.Bold else FontWeight.Normal,
            ),
            maxLines = 1,
            modifier = GlanceModifier.padding(start = 8.dp).defaultWeight(),
        )
        row.suffix?.let { suffix ->
            Text(
                text = suffix,
                style = TextStyle(
                    color = palette.secondary,
                    fontSize = (metrics.fontSize * RowMetrics.SMALL_TEXT_SCALE).sp,
                ),
            )
        }
    }
}

@Composable
private fun FreeTimeRow(row: RowEntry, metrics: RowMetrics, showTimeBars: Boolean, palette: RowPalette) {
    Row(
        modifier = GlanceModifier.fillMaxWidth().height(metrics.lineHeight.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = GlanceModifier.width(metrics.keyline.dp)) {}
        if (showTimeBars) TimeBarSlot(metrics, color = null)
        Text(
            text = row.title ?: "",
            style = TextStyle(
                color = palette.secondary,
                fontSize = (metrics.fontSize * RowMetrics.SMALL_TEXT_SCALE).sp,
                fontStyle = FontStyle.Italic,
            ),
            maxLines = 1,
            modifier = GlanceModifier.padding(start = 8.dp),
        )
    }
}

@Composable
private fun MessageRow(row: RowEntry, metrics: RowMetrics, palette: RowPalette) {
    Text(
        text = row.title ?: "",
        style = TextStyle(color = palette.secondary, fontSize = metrics.fontSize.sp),
        modifier = GlanceModifier.padding(vertical = 4.dp),
    )
}

private fun shortTime(instant: Instant): String =
    DateTimeFormatter.ofPattern("h:mm", Locale.getDefault())
        .format(instant.atZone(ZoneId.systemDefault()))

class CalendarWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CalendarWidget()
}
