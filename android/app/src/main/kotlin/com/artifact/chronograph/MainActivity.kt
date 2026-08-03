package com.artifact.chronograph

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.lifecycle.lifecycleScope
import com.artifact.chronograph.widget.TimeZonesWidgetReceiver
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Generated previews (rate-limited by the OS, ~2 calls/hour) so the
        // widget picker shows real rows instead of the app icon.
        lifecycleScope.launch {
            GlanceAppWidgetManager(this@MainActivity)
                .setWidgetPreviews(TimeZonesWidgetReceiver::class)
        }
        setContent {
            val scheme = if (isSystemInDarkTheme()) {
                dynamicDarkColorScheme(this)
            } else {
                dynamicLightColorScheme(this)
            }
            MaterialTheme(colorScheme = scheme) {
                Home()
            }
        }
    }
}

@Composable
private fun Home() {
    val context = LocalContext.current
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Chronograph", style = MaterialTheme.typography.headlineMedium)
        Button(
            modifier = Modifier.padding(top = 24.dp),
            onClick = {
                AppWidgetManager.getInstance(context).requestPinAppWidget(
                    ComponentName(context, TimeZonesWidgetReceiver::class.java), null, null,
                )
            },
        ) {
            Text("Pin Time Zones widget")
        }
    }
}
