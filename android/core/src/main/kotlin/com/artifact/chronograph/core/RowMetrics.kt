package com.artifact.chronograph.core

/**
 * The row kernel constants — must match apple/Common exactly; see
 * "The row kernel" in docs/specs/2026-08-03-android-port-design.md.
 * Phase 1 carries only enough to prove the module wiring; the full port
 * (WidgetConfig, EventEntry, RowBuilder, Obfuscation) lands next.
 */
enum class FontSize(val sp: Int, val minLines: Int) {
    TINY(11, 6),
    SMALL(13, 5),
    MEDIUM(17, 4),
    LARGE(20, 3),
    HUGE(28, 2),
}

data class RowMetrics(
    val fontSize: Float,
    val lineHeight: Float,
    val keyline: Float,
    val visibleRows: Int,
) {
    companion object {
        const val LINE_SPREAD = 1.5f
        const val SMALL_TEXT_SCALE = 0.66f

        fun forWidget(size: FontSize, widgetHeightDp: Float, compactTime: Boolean = true): RowMetrics {
            val baseLine = size.sp * 1.2f // platform text line-height approximation
            var lineHeight = minOf(baseLine, widgetHeightDp / size.minLines)
            val fontSize = lineHeight * size.sp / baseLine
            lineHeight *= LINE_SPREAD
            return RowMetrics(
                fontSize = fontSize,
                lineHeight = lineHeight,
                keyline = fontSize * (if (compactTime) 2.25f else 2.6f),
                visibleRows = (widgetHeightDp / lineHeight).toInt(),
            )
        }
    }
}
