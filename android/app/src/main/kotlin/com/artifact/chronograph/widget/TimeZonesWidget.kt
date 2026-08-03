package com.artifact.chronograph.widget

import android.content.Context
import android.util.TypedValue
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontStyle
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.artifact.chronograph.R
import com.artifact.chronograph.core.FontSize
import com.artifact.chronograph.core.RowBuilder
import com.artifact.chronograph.core.RowEntry
import com.artifact.chronograph.core.RowMetrics
import com.artifact.chronograph.core.WidgetConfig
import java.time.Instant
import java.time.ZoneId

/**
 * Time Zones widget — Android counterpart of the Swift TimeZoneRowView list.
 * Rows come from :core's RowBuilder; the tick itself is a TextClock so the
 * time stays live between widget updates. The day-part icon and sleeping
 * styling refresh on the normal update cadence (30 min), matching how often
 * they can change.
 */
class TimeZonesWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                TimeZonesContent()
            }
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent {
            GlanceTheme {
                // No host size during preview generation; use the 3×2 bucket.
                TimeZonesContent(previewHeight = 212f)
            }
        }
    }
}

@Composable
private fun TimeZonesContent(previewHeight: Float? = null) {
    val height = previewHeight ?: LocalSize.current.height.value
    val rows = RowBuilder.timezoneRows(WidgetConfig.timezones)
    val metrics = RowMetrics.forWidget(FontSize.MEDIUM, height - 24f, compactTime = false)

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.widgetBackground)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        for (row in rows.take(maxOf(metrics.visibleRows, 1))) {
            TimeZoneRow(row, metrics)
        }
    }
}

@Composable
private fun TimeZoneRow(row: RowEntry, metrics: RowMetrics) {
    val context = LocalContext.current
    val zone = ZoneId.of(row.zoneId ?: "UTC")
    val hour = Instant.now().atZone(zone).hour
    val isLikelySleeping = hour < 7

    val textColor = if (isLikelySleeping) GlanceTheme.colors.onSurfaceVariant else GlanceTheme.colors.onSurface

    Row(
        modifier = GlanceModifier.fillMaxWidth().height(metrics.lineHeight.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AndroidRemoteViews(
            remoteViews = zoneClock(context, zone.id, metrics.fontSize, textColor.getColor(context).toArgb()),
            modifier = GlanceModifier.width(metrics.keyline.dp),
        )
        Text(
            text = row.title ?: "Timezone",
            style = TextStyle(
                color = textColor,
                fontSize = metrics.fontSize.sp,
                fontStyle = if (isLikelySleeping) FontStyle.Italic else FontStyle.Normal,
            ),
            maxLines = 1,
            modifier = GlanceModifier.padding(start = 8.dp).defaultWeight(),
        )
        Text(
            text = dayPartIcon(hour),
            style = TextStyle(fontSize = (metrics.fontSize * RowMetrics.SMALL_TEXT_SCALE).sp),
        )
    }
}

private fun zoneClock(context: Context, zoneId: String, fontSizeSp: Float, colorArgb: Int): RemoteViews =
    RemoteViews(context.packageName, R.layout.row_clock).apply {
        setString(R.id.row_clock, "setTimeZone", zoneId)
        setTextViewTextSize(R.id.row_clock, TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
        setTextColor(R.id.row_clock, colorArgb)
    }

/** Same hour buckets as TimeZoneRowView.getTimeOfDay (first match wins). */
private fun dayPartIcon(hour: Int): String = when (hour) {
    in 6..7 -> "🌄"
    in 8..9 -> "🌅"
    10 -> "🌤️"
    in 11..16 -> "☀️"
    in 17..18 -> "🌇"
    19 -> "🌆"
    in 20..21 -> "🌙"
    22 -> "😴"
    else -> "🌙"
}

class TimeZonesWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TimeZonesWidget()
}
