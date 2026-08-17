package com.artifact.chronograph.widget

import android.content.Context
import android.text.SpannableString
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import android.text.style.SuperscriptSpan
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
import androidx.glance.appwidget.state.getAppWidgetState
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.FontStyle
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.artifact.chronograph.R
import com.artifact.chronograph.core.Cmudict
import com.artifact.chronograph.core.RowBuilder
import com.artifact.chronograph.core.RowEntry
import com.artifact.chronograph.core.RowMetrics
import com.artifact.chronograph.core.WidgetConfig
import com.artifact.chronograph.data.Dictionaries
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
        val prefs = getAppWidgetState(context, PreferencesGlanceStateDefinition, id)
        val config = WidgetPrefs.timezonesConfig(prefs)
        val transparent = WidgetPrefs.isTransparent(prefs)
        val dictionary = Dictionaries.cmudict(context)
        provideContent {
            GlanceTheme {
                TimeZonesContent(config, transparent, dictionary)
            }
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent {
            GlanceTheme {
                // No host size during preview generation; use the 3×2 bucket.
                TimeZonesContent(WidgetConfig.timezones, transparent = false, dictionary = null, previewHeight = 212f)
            }
        }
    }
}

@Composable
private fun TimeZonesContent(
    config: WidgetConfig,
    transparent: Boolean,
    dictionary: Cmudict?,
    previewHeight: Float? = null,
) {
    val height = previewHeight ?: LocalSize.current.height.value
    val rows = RowBuilder.timezoneRows(config)
    // Transparent widgets go full bleed, like iOS fullBleed.
    val vInset = WidgetInsets.vertical(fullBleed = transparent)
    // Compact time (hour + small AM/PM) — the iOS TimeStringView default.
    // Full canvas height, matching where iOS derives its metrics; see CalendarWidget.
    val metrics = RowMetrics.forWidget(config.fontSize, height, compactTime = true)
    val hInset = WidgetInsets.horizontal(fullBleed = transparent, fontSize = metrics.fontSize)
    val palette = rowPalette(transparent)

    // Always set a background: omitting the modifier leaves the launcher's
    // recycled host view holding the previous color (RemoteViews properties
    // are never reset, only overwritten).
    val modifier = GlanceModifier.fillMaxSize()
        .padding(horizontal = hInset.dp, vertical = vInset.dp)
        .background(if (transparent) transparentColor else GlanceTheme.colors.widgetBackground)

    // Top-aligned: ChronographWidget wraps the row stack in
    // .frame(maxHeight: .infinity, alignment: .top) for every content type.
    Column(modifier = modifier) {
        for (row in rows.take(maxOf(metrics.visibleRows, 1))) {
            TimeZoneRow(row, metrics, config, dictionary, palette)
        }
    }
}

@Composable
private fun TimeZoneRow(row: RowEntry, metrics: RowMetrics, config: WidgetConfig, dictionary: Cmudict?, palette: RowPalette) {
    val context = LocalContext.current
    val zone = ZoneId.of(row.zoneId ?: "UTC")
    val hour = Instant.now().atZone(zone).hour
    val isLikelySleeping = hour < 7

    val textColor = if (isLikelySleeping) palette.secondary else palette.primary

    Row(
        modifier = GlanceModifier.fillMaxWidth().height(metrics.lineHeight.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AndroidRemoteViews(
            remoteViews = zoneClock(context, zone.id, metrics.fontSize, textColor.getColor(context).toArgb()),
            // Wider than the keyline: iOS keylines are minWidth and stretch for
            // two-digit hours like "11 PM"; a Glance width is fixed, so it must
            // pre-fit the widest time. Narrowing this to keyline clips the
            // meridiem off "11 AM" and "12 AM" — verified, don't.
            modifier = GlanceModifier.width((metrics.fontSize * 2.9f).dp),
        )
        Text(
            text = config.obfuscation.transform(row.title ?: "Timezone", dictionary),
            style = TextStyle(
                color = textColor,
                fontSize = metrics.fontSize.sp,
                fontStyle = if (isLikelySleeping) FontStyle.Italic else FontStyle.Normal,
            ),
            maxLines = 1,
            // No defaultWeight: TimeZoneRowView has no Spacer, so the glyph packs
            // straight after the city name instead of being pushed to the edge.
            modifier = GlanceModifier.padding(start = metrics.columnSpacing.dp),
        )
        // TimeZoneRowView draws the day-part symbol at .imageScale(.small).
        Text(
            text = dayPartIcon(hour),
            style = TextStyle(fontSize = metrics.smallFontSize.sp),
            modifier = GlanceModifier.padding(start = metrics.columnSpacing.dp),
        )
    }
}

/**
 * iOS TimeStringView compact + showAMPM: big hour, small raised meridiem, no
 * minutes. Spans on the format pattern survive TextClock's formatting, so the
 * live clock keeps the mixed sizing. Both format slots get the same pattern so
 * the layout doesn't shift with the device's 24-hour preference.
 */
private fun compactHourFormat(): CharSequence =
    SpannableString("h a").apply {
        setSpan(RelativeSizeSpan(0.66f), 1, 3, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
        setSpan(SuperscriptSpan(), 1, 3, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
    }

private fun zoneClock(context: Context, zoneId: String, fontSizeSp: Float, colorArgb: Int): RemoteViews =
    RemoteViews(context.packageName, R.layout.row_clock).apply {
        setString(R.id.row_clock, "setTimeZone", zoneId)
        setCharSequence(R.id.row_clock, "setFormat12Hour", compactHourFormat())
        setCharSequence(R.id.row_clock, "setFormat24Hour", compactHourFormat())
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

internal val transparentColor = androidx.glance.unit.ColorProvider(
    androidx.compose.ui.graphics.Color.Transparent,
)

class TimeZonesWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TimeZonesWidget()
}
