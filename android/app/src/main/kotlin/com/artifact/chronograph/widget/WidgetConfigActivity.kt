package com.artifact.chronograph.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.Preferences
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.getAppWidgetState
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.lifecycle.lifecycleScope
import kotlin.math.roundToInt
import com.artifact.chronograph.core.FontSize
import com.artifact.chronograph.core.ObfuscationStyle
import kotlinx.coroutines.launch

/** Preset accents; iOS exposes free-form hex fields, presets fit a phone form. */
private val accentPresets = listOf(
    "" to "Default",
    "#db4437" to "Red",
    "#4285f4" to "Blue",
    "#0f9d58" to "Green",
    "#f4b400" to "Amber",
)

/**
 * Per-widget options — Android counterpart of the iOS AppIntents config
 * sheet. Launched from the widget picker (configure) and the long-press
 * pencil (reconfigure); writes Glance per-widget state and refreshes.
 */
class WidgetConfigActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))

        val providerClass = AppWidgetManager.getInstance(this)
            .getAppWidgetInfo(appWidgetId)?.provider?.className.orEmpty()
        val isCalendar = providerClass.contains("Calendar")

        setContent {
            val scheme = if (isSystemInDarkTheme()) {
                dynamicDarkColorScheme(this)
            } else {
                dynamicLightColorScheme(this)
            }
            MaterialTheme(colorScheme = scheme) {
                var loaded by remember { mutableStateOf<Preferences?>(null) }
                if (loaded == null) {
                    lifecycleScope.launch {
                        val glanceId = GlanceAppWidgetManager(this@WidgetConfigActivity)
                            .getGlanceIdBy(appWidgetId)
                        loaded = getAppWidgetState(
                            this@WidgetConfigActivity, PreferencesGlanceStateDefinition, glanceId,
                        )
                    }
                }
                loaded?.let { prefs ->
                    ConfigScreen(prefs, isCalendar) { apply ->
                        lifecycleScope.launch {
                            val glanceId = GlanceAppWidgetManager(this@WidgetConfigActivity)
                                .getGlanceIdBy(appWidgetId)
                            updateAppWidgetState(this@WidgetConfigActivity, glanceId) { apply(it) }
                            val widget = if (isCalendar) CalendarWidget() else TimeZonesWidget()
                            widget.update(this@WidgetConfigActivity, glanceId)
                            setResult(
                                RESULT_OK,
                                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                            )
                            finish()
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ConfigScreen(
    initial: Preferences,
    isCalendar: Boolean,
    onDone: ((androidx.datastore.preferences.core.MutablePreferences) -> Unit) -> Unit,
) {
    var fontSize by remember { mutableStateOf(WidgetPrefs.fontSize(initial)) }
    var obfuscation by remember { mutableStateOf(WidgetPrefs.obfuscation(initial)) }
    var transparent by remember { mutableStateOf(WidgetPrefs.isTransparent(initial)) }
    var accent by remember { mutableStateOf(initial[WidgetPrefs.ACCENT_COLOR] ?: "") }
    var allDay by remember { mutableStateOf(initial[WidgetPrefs.ALL_DAY_EVENTS] != false) }
    var multiDay by remember { mutableStateOf(initial[WidgetPrefs.MULTI_DAY_EVENTS] != false) }
    var timeBars by remember { mutableStateOf(initial[WidgetPrefs.TIME_BARS] != false) }
    var freeTime by remember { mutableStateOf(initial[WidgetPrefs.FREE_TIME] == true) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surface)
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text("Widget options", style = MaterialTheme.typography.headlineSmall)

        SectionLabel("Font Size")
        Row(verticalAlignment = Alignment.CenterVertically) {
            Slider(
                value = fontSize.ordinal.toFloat(),
                onValueChange = { fontSize = FontSize.entries[it.roundToInt()] },
                valueRange = 0f..(FontSize.entries.size - 1).toFloat(),
                steps = FontSize.entries.size - 2,
                modifier = Modifier.weight(1f),
            )
            Text(
                fontSize.label,
                style = MaterialTheme.typography.labelLarge,
                modifier = Modifier.padding(start = 16.dp).width(64.dp),
            )
        }

        SectionLabel("Obfuscation")
        ChipRow(
            options = ObfuscationStyle.entries.map { it to it.label },
            selected = obfuscation,
            onSelect = { obfuscation = it },
        )

        SectionLabel("Appearance")
        LabeledSwitch("Transparent background", transparent) { transparent = it }

        if (isCalendar) {
            SectionLabel("Accent Color")
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                for ((hex, name) in accentPresets) {
                    AccentSwatch(hex, name, selected = accent == hex) { accent = hex }
                }
            }

            SectionLabel("Calendar")
            LabeledSwitch("All-day events", allDay) { allDay = it }
            LabeledSwitch("Multi-day events", multiDay) { multiDay = it }
            LabeledSwitch("Time bars", timeBars) { timeBars = it }
            LabeledSwitch("Free time", freeTime) { freeTime = it }
        }

        Button(
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            onClick = {
                onDone { prefs ->
                    prefs[WidgetPrefs.FONT_SIZE] = fontSize.name
                    prefs[WidgetPrefs.OBFUSCATION] = obfuscation.name
                    prefs[WidgetPrefs.TRANSPARENT_BACKGROUND] = transparent
                    prefs[WidgetPrefs.ACCENT_COLOR] = accent
                    prefs[WidgetPrefs.ALL_DAY_EVENTS] = allDay
                    prefs[WidgetPrefs.MULTI_DAY_EVENTS] = multiDay
                    prefs[WidgetPrefs.TIME_BARS] = timeBars
                    prefs[WidgetPrefs.FREE_TIME] = freeTime
                }
            },
        ) {
            Text("Done")
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 12.dp),
    )
}

@Composable
private fun <T> ChipRow(options: List<Pair<T, String>>, selected: T, onSelect: (T) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        for ((value, label) in options) {
            FilterChip(
                selected = value == selected,
                onClick = { onSelect(value) },
                label = { Text(label) },
            )
        }
    }
}

@Composable
private fun LabeledSwitch(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun AccentSwatch(hex: String, name: String, selected: Boolean, onClick: () -> Unit) {
    val color = if (hex.isEmpty()) {
        MaterialTheme.colorScheme.secondary
    } else {
        Color(android.graphics.Color.parseColor(hex))
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(if (selected) 40.dp else 32.dp)
                .background(color, CircleShape)
                .clickable(onClick = onClick),
        )
        if (selected) {
            Text(name, style = MaterialTheme.typography.labelSmall)
        }
    }
}

private val FontSize.label: String
    get() = name.lowercase().replaceFirstChar { it.uppercase() }

private val ObfuscationStyle.label: String
    get() = name.lowercase().replaceFirstChar { it.uppercase() }
