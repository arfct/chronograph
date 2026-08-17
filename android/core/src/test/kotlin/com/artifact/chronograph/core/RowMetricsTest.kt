package com.artifact.chronograph.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class RowMetricsTest {
    @Test
    fun `medium font on a systemMedium-like widget yields four rows`() {
        // 159dp is the iPhone systemSmall/Medium height. Working the iOS kernel
        // through by hand: .body has pointSize 17 and lineHeight 22, so
        // min(22, 159/4) = 22, ×1.5 spread = 33, and floor(159/33) = 4.
        //
        // This asserted 5 while RowMetrics approximated the base line height as
        // sp × 1.2 (20.4 rather than 22), which shrank every row by ~8% and let
        // an extra one in. The real UIFont metrics now live on FontSize.
        val metrics = RowMetrics.forWidget(FontSize.MEDIUM, widgetHeightDp = 159f)
        assertEquals(4, metrics.visibleRows)
        assertEquals(33f, metrics.lineHeight)
        assertEquals(17f, metrics.fontSize)
    }

    @Test
    fun `derived metrics track the iOS RowViewConfig ratios`() {
        val metrics = RowMetrics.forWidget(FontSize.MEDIUM, widgetHeightDp = 159f)
        // config.smallFontSize = fontSize * 0.66
        assertEquals(17f * 0.66f, metrics.smallFontSize)
        // config.smallLineHeight = lineHeight * 0.66
        assertEquals(33f * 0.66f, metrics.smallLineHeight)
        // config.columnSpacing = fontSize / 6
        assertEquals(17f / 6f, metrics.columnSpacing)
        // config.keyline = fontSize * 2.25 with compactTime
        assertEquals(17f * 2.25f, metrics.keyline)
    }

    @Test
    fun `line height is capped by minimum line count`() {
        val metrics = RowMetrics.forWidget(FontSize.HUGE, widgetHeightDp = 60f)
        // 60dp / 2 minLines = 30dp cap, then ×1.5 spread
        assertEquals(45f, metrics.lineHeight)
    }
}
