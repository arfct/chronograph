package com.artifact.chronograph.widget

/**
 * Container padding, ported from ChronographWidget.swift:
 *
 *     let hPadding = fullBleed ? margins.top / 8 : margins.leading
 *     let vPadding = fullBleed ? margins.top / 8 : margins.top / 2
 *     insets = EdgeInsets(top: vPadding,
 *                         leading: min(hPadding, fontSize / 2), …)
 *
 * `margins` is SwiftUI's `widgetContentMargins`, 16pt on every side for system
 * widgets. A transparent widget is the full-bleed case, so it keeps a 2pt hair
 * of padding rather than going flush to the edge — the previous flat
 * `if (transparent) 0 else 12` was wrong on both branches.
 */
internal object WidgetInsets {

    /** SwiftUI's widgetContentMargins for a system-family widget. */
    private const val CONTENT_MARGIN = 16f

    fun horizontal(fullBleed: Boolean, fontSize: Float): Float {
        val h = if (fullBleed) CONTENT_MARGIN / 8f else CONTENT_MARGIN
        return minOf(h, fontSize / 2f)
    }

    fun vertical(fullBleed: Boolean): Float =
        if (fullBleed) CONTENT_MARGIN / 8f else CONTENT_MARGIN / 2f
}
