package com.artifact.chronograph.widget

import android.app.WallpaperColors
import android.app.WallpaperManager
import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.glance.GlanceTheme
import androidx.glance.unit.ColorProvider

/** Primary/secondary text colors for widget rows. */
data class RowPalette(
    val primary: ColorProvider,
    val secondary: ColorProvider,
)

/**
 * On a transparent background, text follows the wallpaper instead of the
 * theme: WallpaperColors' HINT_SUPPORTS_DARK_TEXT is the same signal the
 * launcher uses for its own clock. Wallpaper-wide only — the platform
 * doesn't expose per-position contrast. Falls back to theme colors when the
 * wallpaper reports no hints (some live wallpapers).
 */
@Composable
fun rowPalette(transparent: Boolean): RowPalette {
    val themed = RowPalette(GlanceTheme.colors.onSurface, GlanceTheme.colors.onSurfaceVariant)
    if (!transparent) return themed
    return wallpaperPalette(androidx.glance.LocalContext.current) ?: themed
}

private fun wallpaperPalette(context: Context): RowPalette? {
    val colors = runCatching {
        WallpaperManager.getInstance(context).getWallpaperColors(WallpaperManager.FLAG_SYSTEM)
    }.getOrNull() ?: return null

    val darkText = colors.colorHints and WallpaperColors.HINT_SUPPORTS_DARK_TEXT != 0
    return if (darkText) {
        RowPalette(
            primary = ColorProvider(Color(0xF2000000)),
            secondary = ColorProvider(Color(0x99000000)),
        )
    } else {
        RowPalette(
            primary = ColorProvider(Color.White),
            secondary = ColorProvider(Color(0xB3FFFFFF)),
        )
    }
}
