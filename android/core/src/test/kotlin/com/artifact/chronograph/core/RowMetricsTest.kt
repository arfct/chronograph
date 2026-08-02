package com.artifact.chronograph.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class RowMetricsTest {
    @Test
    fun `medium font on a systemMedium-like widget yields five rows`() {
        // 159dp is the iPhone systemSmall/Medium height the iOS kernel was
        // verified against (5 rows at medium): parity anchor, not gospel.
        val metrics = RowMetrics.forWidget(FontSize.MEDIUM, widgetHeightDp = 159f)
        assertEquals(5, metrics.visibleRows)
    }

    @Test
    fun `line height is capped by minimum line count`() {
        val metrics = RowMetrics.forWidget(FontSize.HUGE, widgetHeightDp = 60f)
        // 60dp / 2 minLines = 30dp cap, then ×1.5 spread
        assertEquals(45f, metrics.lineHeight)
    }
}
