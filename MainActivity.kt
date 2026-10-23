package com.tactical.tibia.tibia_radar

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tactical.tibia/radar"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRadarService" -> {
                    val targets = call.argument<List<String>>("targets") ?: emptyList()
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit().putStringSet("direct_radar_targets", targets.toSet()).apply()

                    val intent = Intent(this, RadarService::class.java)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "stopRadarService" -> {
                    val intent = Intent(this, RadarService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "updateTargets" -> {
                    val targets = call.argument<List<String>>("targets") ?: emptyList()
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit().putStringSet("direct_radar_targets", targets.toSet()).apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
