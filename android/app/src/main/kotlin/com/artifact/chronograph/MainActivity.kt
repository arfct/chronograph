package com.artifact.chronograph

import android.Manifest
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.Slider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.updateAll
import androidx.lifecycle.lifecycleScope
import com.artifact.chronograph.core.FontSize
import com.artifact.chronograph.data.CalendarRepository
import com.artifact.chronograph.widget.AppPrefs
import com.artifact.chronograph.widget.CalendarWidget
import com.artifact.chronograph.widget.CalendarWidgetReceiver
import com.artifact.chronograph.widget.TimeZonesWidgetReceiver
import com.artifact.chronograph.widget.label
import kotlin.math.roundToInt
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Generated previews (rate-limited by the OS, ~2 calls/hour) so the
        // widget picker shows real rows instead of the app icon.
        lifecycleScope.launch {
            val manager = GlanceAppWidgetManager(this@MainActivity)
            manager.setWidgetPreviews(TimeZonesWidgetReceiver::class)
            manager.setWidgetPreviews(CalendarWidgetReceiver::class)
        }
        setContent {
            val scheme = if (isSystemInDarkTheme()) {
                dynamicDarkColorScheme(this)
            } else {
                dynamicLightColorScheme(this)
            }
            MaterialTheme(colorScheme = scheme) {
                Home(onCalendarPermissionGranted = {
                    lifecycleScope.launch { CalendarWidget().updateAll(this@MainActivity) }
                })
            }
        }
    }
}

@Composable
private fun Home(onCalendarPermissionGranted: () -> Unit) {
    val context = LocalContext.current
    var hasCalendarAccess by remember { mutableStateOf(CalendarRepository.hasPermission(context)) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        hasCalendarAccess = granted
        if (granted) onCalendarPermissionGranted()
    }

    fun pin(receiver: Class<out GlanceAppWidgetReceiver>) {
        AppWidgetManager.getInstance(context)
            .requestPinAppWidget(ComponentName(context, receiver), null, null)
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Chronograph", style = MaterialTheme.typography.headlineMedium)
        if (!hasCalendarAccess) {
            Button(onClick = { permissionLauncher.launch(Manifest.permission.READ_CALENDAR) }) {
                Text("Allow calendar access")
            }
        }
        Button(
            enabled = hasCalendarAccess,
            onClick = { pin(CalendarWidgetReceiver::class.java) },
        ) {
            Text("Pin Calendar widget")
        }
        OutlinedButton(onClick = { pin(TimeZonesWidgetReceiver::class.java) }) {
            Text("Pin Time Zones widget")
        }
        DefaultSizeSetting()
    }
}

/**
 * App-wide Default Size, the counterpart of the iOS Display Options picker.
 * Widgets whose size is Default follow it; the rest keep their own.
 */
@Composable
private fun DefaultSizeSetting() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var size by remember { mutableStateOf(AppPrefs.defaultFontSize(context)) }

    Text(
        "Default size",
        style = MaterialTheme.typography.titleSmall,
        modifier = Modifier.padding(top = 24.dp),
    )
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Slider(
            value = size.ordinal.toFloat(),
            onValueChange = { size = FontSize.entries[it.roundToInt()] },
            onValueChangeFinished = {
                scope.launch { AppPrefs.setDefaultFontSize(context, size) }
            },
            valueRange = 0f..(FontSize.entries.size - 1).toFloat(),
            steps = FontSize.entries.size - 2,
            modifier = Modifier.weight(1f),
        )
        Text(
            size.label,
            style = MaterialTheme.typography.labelLarge,
            modifier = Modifier.padding(start = 16.dp).width(64.dp),
        )
    }
}
