package com.artifact.chronograph.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontStyle
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.artifact.chronograph.MainActivity
import com.artifact.chronograph.core.CalendarItem
import com.artifact.chronograph.core.FontSize
import com.artifact.chronograph.core.RowBuilder
import com.artifact.chronograph.core.RowEntry
import com.artifact.chronograph.core.RowMetrics
import com.artifact.chronograph.core.WidgetConfig
import com.artifact.chronograph.data.CalendarRepository
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Calendar widget — same TimelineEngine shape as iOS: fetch items, build rows
 * in :core, mark conflicts, render. Missing permission renders the same kind
 * of error row the Swift engine emits (tap opens the app to grant).
 */
class CalendarWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val rows = buildRows(context)
        provideContent {
            GlanceTheme {
                CalendarContent(rows)
            }
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent {
            GlanceTheme {
                CalendarContent(sampleRows(), previewHeight = 212f)
            }
        }
    }

    private fun buildRows(context: Context): List<RowEntry> {
        if (!CalendarRepository.hasPermission(context)) {
            return listOf(RowEntry(type = "error", title = "Enable access to calendar in settings"))
        }
        val now = Instant.now()
        val rows = RowBuilder.calendarRows(WidgetConfig.calendar, CalendarRepository.queryItems(context, now), now)
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
private fun CalendarContent(rows: List<RowEntry>, previewHeight: Float? = null) {
    val height = previewHeight ?: LocalSize.current.height.value
    // iOS keylines are minWidth and can grow; Glance widths are fixed, so use
    // the wide keyline to fit five-character times like "10:43".
    val metrics = RowMetrics.forWidget(FontSize.MEDIUM, height - 24f, compactTime = false)
    val now = Instant.now()

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.widgetBackground)
            .padding(12.dp)
            .clickable(actionStartActivity<MainActivity>()),
    ) {
        for (row in rows.take(maxOf(metrics.visibleRows, 1))) {
            when (row.type) {
                "header" -> HeaderRow(row, metrics)
                "error", "empty" -> MessageRow(row, metrics)
                "free" -> FreeTimeRow(row, metrics)
                else -> EventRow(row, metrics, now)
            }
        }
    }
}

@Composable
private fun HeaderRow(row: RowEntry, metrics: RowMetrics) {
    Row(
        modifier = GlanceModifier.fillMaxWidth().height(metrics.lineHeight.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = GlanceModifier.width(metrics.keyline.dp)) {}
        Text(
            text = row.title ?: "",
            style = TextStyle(
                color = GlanceTheme.colors.onSurface,
                fontSize = metrics.fontSize.sp,
                fontWeight = FontWeight.Bold,
            ),
            maxLines = 1,
            modifier = GlanceModifier.padding(start = 8.dp),
        )
        val allDayTitles = row.allDayItems.orEmpty().mapNotNull { it.item?.title }
        if (allDayTitles.isNotEmpty()) {
            Text(
                text = allDayTitles.joinToString(", "),
                style = TextStyle(
                    color = GlanceTheme.colors.onSurfaceVariant,
                    fontSize = (metrics.fontSize * RowMetrics.SMALL_TEXT_SCALE).sp,
                ),
                maxLines = 1,
                modifier = GlanceModifier.padding(start = 8.dp).defaultWeight(),
            )
        }
    }
}

@Composable
private fun EventRow(row: RowEntry, metrics: RowMetrics, now: Instant) {
    val hasEnded = row.hasEnded(now)
    val isHappening = row.isHappening(now)
    val color = if (hasEnded) GlanceTheme.colors.onSurfaceVariant else GlanceTheme.colors.onSurface

    Row(
        modifier = GlanceModifier.fillMaxWidth().height(metrics.lineHeight.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = GlanceModifier.width(metrics.keyline.dp),
            contentAlignment = Alignment.CenterEnd,
        ) {
            Text(
                text = row.startAt?.let(::shortTime) ?: "",
                style = TextStyle(color = color, fontSize = metrics.fontSize.sp),
                maxLines = 1,
            )
        }
        Text(
            text = row.item?.title ?: row.title ?: "Event",
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
                    color = GlanceTheme.colors.onSurfaceVariant,
                    fontSize = (metrics.fontSize * RowMetrics.SMALL_TEXT_SCALE).sp,
                ),
            )
        }
    }
}

@Composable
private fun FreeTimeRow(row: RowEntry, metrics: RowMetrics) {
    Row(
        modifier = GlanceModifier.fillMaxWidth().height(metrics.lineHeight.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = GlanceModifier.width(metrics.keyline.dp)) {}
        Text(
            text = row.title ?: "",
            style = TextStyle(
                color = GlanceTheme.colors.onSurfaceVariant,
                fontSize = (metrics.fontSize * RowMetrics.SMALL_TEXT_SCALE).sp,
                fontStyle = FontStyle.Italic,
            ),
            maxLines = 1,
            modifier = GlanceModifier.padding(start = 8.dp),
        )
    }
}

@Composable
private fun MessageRow(row: RowEntry, metrics: RowMetrics) {
    Text(
        text = row.title ?: "",
        style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = metrics.fontSize.sp),
        modifier = GlanceModifier.padding(vertical = 4.dp),
    )
}

private fun shortTime(instant: Instant): String =
    DateTimeFormatter.ofPattern("h:mm", Locale.getDefault())
        .format(instant.atZone(ZoneId.systemDefault()))

class CalendarWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CalendarWidget()
}
