package com.artifact.chronograph.core

/**
 * The row kernel constants — must match apple/Common exactly; see
 * "The row kernel" in docs/specs/2026-08-03-android-port-design.md.
 *
 * iOS builds these from `UIFont.preferredFont(forTextStyle:)`, so both the point
 * size and the line height come from the platform font. `sp` mirrors the point
 * size at the default Dynamic Type setting and `lineHeightSp` mirrors that
 * font's `lineHeight` — the ratio is not constant across the scale (1.18 at
 * caption2, 1.38 at footnote), so a single multiplier cannot reproduce it and
 * row heights drift by ~8% at body size.
 */
enum class FontSize(val sp: Int, val lineHeightSp: Int, val minLines: Int) {
    TINY(11, 13, 6),     // UIFont.TextStyle.caption2
    SMALL(13, 18, 5),    // .footnote
    MEDIUM(17, 22, 4),   // .body
    LARGE(20, 25, 3),    // .title3
    HUGE(28, 34, 2),     // .title1
}

data class RowMetrics(
    val fontSize: Float,
    val lineHeight: Float,
    val keyline: Float,
    val visibleRows: Int,
) {
    /** `config.smallFontSize` — fontSize * 0.66. */
    val smallFontSize: Float get() = fontSize * SMALL_TEXT_SCALE

    /** `config.smallLineHeight` — lineHeight * 0.66. */
    val smallLineHeight: Float get() = lineHeight * SMALL_TEXT_SCALE

    /** `config.columnSpacing` — the gap between every row column. */
    val columnSpacing: Float get() = fontSize / 6f

    companion object {
        const val LINE_SPREAD = 1.5f
        const val SMALL_TEXT_SCALE = 0.66f

        fun forWidget(size: FontSize, widgetHeightDp: Float, compactTime: Boolean = true): RowMetrics {
            val baseLine = size.lineHeightSp.toFloat()
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
