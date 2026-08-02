package com.artifact.chronograph.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontFamily
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle

/**
 * Phase-1 spike (throwaway; see docs/specs/2026-08-03-android-port-design.md).
 * One widget probing the four open risks:
 *  1. Size buckets — SizeMode.Exact + a LocalSize readout, so resizing the
 *     widget on the launcher reveals the dp grid.
 *  2. Time bar — fractional-width Box computed from LocalSize (no canvas).
 *  3. Custom font — a row requesting FontFamily("ishihara"); if it renders
 *     identically to the system row, Glance can't resolve custom families.
 *  4. Material You — GlanceTheme colors for background/text.
 *  (5. keyguard category is probed by spike_widget_info.xml, not this class.)
 */
class SpikeWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                SpikeContent()
            }
        }
    }

    @Composable
    private fun SpikeContent() {
        val size = LocalSize.current
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(GlanceTheme.colors.widgetBackground)
                .padding(12.dp)
        ) {
            Text(
                text = "${size.width.value.toInt()} × ${size.height.value.toInt()} dp",
                style = TextStyle(
                    color = GlanceTheme.colors.onSurface,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                ),
            )
            Text(
                text = "System font — Tiim Stǽndʌp ⠞⠑⠁⠍",
                style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 15.sp),
            )
            Text(
                text = "Ishihara? — Tiim Stǽndʌp",
                style = TextStyle(
                    color = GlanceTheme.colors.onSurface,
                    fontSize = 15.sp,
                    fontFamily = FontFamily("ishihara"),
                ),
            )
            Text(
                text = "Monospace control row",
                style = TextStyle(
                    color = GlanceTheme.colors.onSurface,
                    fontSize = 15.sp,
                    fontFamily = FontFamily.Monospace,
                ),
            )
            TimeBar(fraction = 0.35f, totalWidth = size.width.value)
            TimeBar(fraction = 0.8f, totalWidth = size.width.value)
        }
    }

    /** Fractional bar without a canvas: explicit dp width from LocalSize. */
    @Composable
    private fun TimeBar(fraction: Float, totalWidth: Float) {
        val usable = totalWidth - 24f // padding
        Row(modifier = GlanceModifier.fillMaxWidth().padding(top = 6.dp)) {
            Box(
                modifier = GlanceModifier
                    .width((usable * fraction).dp)
                    .height(4.dp)
                    .cornerRadius(2.dp)
                    .background(GlanceTheme.colors.primary)
            ) {}
            Box(
                modifier = GlanceModifier
                    .width((usable * (1 - fraction)).dp)
                    .height(4.dp)
                    .background(ColorProvider(Color(0x22888888), Color(0x22888888)))
            ) {}
        }
    }
}

class SpikeWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = SpikeWidget()
}
