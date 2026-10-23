package com.tactical.tibia.spy_ferobra

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tactical.tibia/radar"

    override fun onResume() {
        super.onResume()
        val intent = Intent(this, RadarService::class.java).apply {
            action = RadarService.ACTION_STOP_SIREN
        }
        startService(intent)
    }

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
                    val intent = Intent(this, RadarService::class.java)
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "syncTargets" -> {
                    val json = call.argument<String>("json") ?: "[]"
                    RadarService.targetsInMemory = json
                    val intent = Intent(this, RadarService::class.java).apply {
                        action = RadarService.ACTION_SYNC_TARGETS
                        putExtra("targets_json", json)
                    }
                    startService(intent)
                    result.success(true)
                }
                "stopRadarService" -> {
                    val intent = Intent(this, RadarService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "stopSiren" -> {
                    val intent = Intent(this, RadarService::class.java).apply {
                        action = RadarService.ACTION_STOP_SIREN
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
