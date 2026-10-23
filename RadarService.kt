package com.tactical.tibia.spy_ferobra

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.speech.tts.TextToSpeech
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class RadarService : Service(), TextToSpeech.OnInitListener {
    private var scheduler: ScheduledExecutorService? = null
    private val previousOnline = HashMap<String, HashSet<String>>()
    private var isFirstRun = true
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    companion object {
        const val ACTION_STOP_SIREN = "com.tactical.tibia.ACTION_STOP_SIREN"
        const val ACTION_SYNC_TARGETS = "com.tactical.tibia.ACTION_SYNC_TARGETS"
        var targetsInMemory: String = "[]"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = tts?.setLanguage(Locale.getDefault())
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.language = Locale("es")
            }
            tts?.setSpeechRate(0.95f)
            ttsReady = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_SIREN) {
            try { tts?.stop() } catch (e: Exception) {}
            val notifyMgr = getSystemService(NotificationManager::class.java)
            notifyMgr?.cancel(9999)
            return START_STICKY
        }

        if (intent?.action == ACTION_SYNC_TARGETS) {
            val json = intent.getStringExtra("targets_json")
            if (json != null && json.isNotEmpty()) {
                targetsInMemory = json
            }
            return START_STICKY
        }

        val notification = createPersistentNotification("Spy Ferobra: Vigilancia 24/7 en segundo plano")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1001, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(1001, notification)
        }

        startMonitoring()
        return START_STICKY
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            val statusChannel = NotificationChannel(
                "radar_status_v3",
                "Estado Spy Ferobra",
                NotificationManager.IMPORTANCE_LOW
            )
            manager?.createNotificationChannel(statusChannel)

            val alertChannel = NotificationChannel(
                "radar_alerts_v3",
                "Alertas Tácticas de Voz",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alertas de voz para entradas, salidas y muertes"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 180, 100, 180)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            manager?.createNotificationChannel(alertChannel)
        }
    }

    private fun createPersistentNotification(text: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, "radar_status_v3")
            .setContentTitle("🛰️ SPY FEROBRA // ACTIVO")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startMonitoring() {
        scheduler?.shutdownNow()
        scheduler = Executors.newSingleThreadScheduledExecutor()
        scheduler?.scheduleWithFixedDelay({
            try {
                scanWorlds()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, 2, 30, TimeUnit.SECONDS)
    }

    // VOZ A VOLUMEN DE ALARMA
    private fun speakText(text: String) {
        try {
            if (ttsReady && tts != null) {
                val params = Bundle().apply {
                    putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_ALARM)
                    putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
                }
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "SPY_VOICE")
            }
        } catch (e: Exception) {}
    }

    // SIRENA DE 1 SEGUNDO
    private fun playOneSecondSiren() {
        Thread {
            try {
                Thread.sleep(2000)
                val sampleRate = 22050
                val durationSeconds = 1.0
                val totalSamples = (sampleRate * durationSeconds).toInt()
                val buffer = ShortArray(totalSamples)
                var phase = 0.0

                for (i in 0 until totalSamples) {
                    val t = i.toDouble() / sampleRate
                    val freq = 700.0 + 350.0 * Math.sin(2.0 * Math.PI * 1.5 * t)
                    phase += 2.0 * Math.PI * freq / sampleRate
                    buffer[i] = (Math.sin(phase) * 32767 * 0.95).toInt().toShort()
                }

                val minBuf = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
                val track = AudioTrack(
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
                    AudioFormat.Builder().setSampleRate(sampleRate).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).setEncoding(AudioFormat.ENCODING_PCM_16BIT).build(),
                    maxOf(buffer.size * 2, minBuf),
                    AudioTrack.MODE_STREAM,
                    AudioManager.AUDIO_SESSION_ID_GENERATE
                )
                track.play()
                track.write(buffer, 0, buffer.size)
                track.stop()
                track.release()
            } catch (e: Exception) {}
        }.start()
    }

    private fun scanWorlds() {
        var targetsArray = JSONArray(targetsInMemory)
        if (targetsArray.length() == 0) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val stored = prefs.getString("flutter.spy_targets_json", null) ?: prefs.getString("spy_targets_json", null) ?: "[]"
            targetsArray = JSONArray(stored)
        }

        if (targetsArray.length() == 0) return

        val worldsToScan = HashSet<String>()
        val targetObjects = ArrayList<JSONObject>()

        for (i in 0 until targetsArray.length()) {
            val obj = targetsArray.getJSONObject(i)
            targetObjects.add(obj)
            val w = obj.optString("world", "Ferobra").trim()
            if (w.isNotEmpty()) worldsToScan.add(w)
        }

        for (worldName in worldsToScan) {
            val currentOnlineMap = HashMap<String, String>()
            try {
                val url = URL("https://api.tibiadata.com/v4/world/$worldName")
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.requestMethod = "GET"
                // User-Agent oficial para que Cloudflare nunca bloquee las peticiones en segundo plano
                conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36")

                if (conn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream))
                    val sb = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) { sb.append(line) }
                    reader.close()

                    val json = JSONObject(sb.toString())
                    val playersArr = json.optJSONObject("world")?.optJSONArray("online_players")

                    if (playersArr != null) {
                        for (i in 0 until playersArr.length()) {
                            val p = playersArr.getJSONObject(i)
                            val name = p.optString("name").trim().lowercase()
                            val lvl = p.optInt("level")
                            val voc = p.optString("vocation")
                            currentOnlineMap[name] = "$lvl - $voc"
                        }
                    }
                }
            } catch (e: Exception) {
                continue
            }

            if (currentOnlineMap.isEmpty()) continue

            val prevOnline = previousOnline[worldName] ?: HashSet()

            if (!isFirstRun && prevOnline.isNotEmpty()) {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

                for (targetObj in targetObjects) {
                    val targetName = targetObj.optString("name").trim().lowercase()
                    val targetWorld = targetObj.optString("world", "Ferobra").trim()
                    val targetType = targetObj.optString("type", "enemigo").trim().lowercase()

                    if (!targetWorld.equals(worldName, ignoreCase = true)) continue

                    val muteLogin = prefs.getBoolean("flutter.mute_login_$targetName", false) || prefs.getBoolean("mute_login_$targetName", false)
                    val muteLogout = prefs.getBoolean("flutter.mute_logout_$targetName", false) || prefs.getBoolean("mute_logout_$targetName", false)
                    val charDisplay = targetObj.optString("name").trim()

                    // LOGIN: "Tu amigo Fiodor en Ferobra conectó" / "Tu enemigo..."
                    if (currentOnlineMap.containsKey(targetName) && !prevOnline.contains(targetName)) {
                        if (!muteLogin) {
                            val msg = if (targetType == "amigo") "Tu amigo $charDisplay en $targetWorld conectó." else "Tu enemigo $charDisplay en $targetWorld conectó."
                            speakText(msg)
                            showEventNotification(charDisplay, targetWorld, "conectó", targetType == "amigo")
                        }
                    }

                    // LOGOUT: "Tu amigo Fiodor en Ferobra desconectó" / "Tu enemigo..." (+ sirena 1s)
                    if (!currentOnlineMap.containsKey(targetName) && prevOnline.contains(targetName)) {
                        if (!muteLogout) {
                            val msg = if (targetType == "amigo") "Tu amigo $charDisplay en $targetWorld desconectó." else "Tu enemigo $charDisplay en $targetWorld desconectó."
                            speakText(msg)
                            if (targetType != "amigo") {
                                playOneSecondSiren()
                            }
                            showEventNotification(charDisplay, targetWorld, "desconectó", targetType == "amigo")
                        }
                    }
                }
            }

            previousOnline[worldName] = HashSet(currentOnlineMap.keys)
        }

        if (isFirstRun) isFirstRun = false
    }

    private fun showEventNotification(name: String, world: String, action: String, isFriend: Boolean) {
        wakeUpScreen()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, (System.currentTimeMillis() % 10000).toInt(), launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val title = if (isFriend) "🛡️ [AMIGO EN $world]" else "⚔️ [ENEMIGO EN $world]"
        val text = if (isFriend) "Tu amigo $name $action en $world." else "Tu enemigo $name $action en $world."

        val builder = NotificationCompat.Builder(this, "radar_alerts_v3")
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 150, 100, 150))

        val notifyMgr = getSystemService(NotificationManager::class.java)
        notifyMgr?.notify((System.currentTimeMillis() % 100000).toInt(), builder.build())
    }

    private fun wakeUpScreen() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "spy_ferobra:screen_wake"
            )
            wl.acquire(6000)
        } catch (e: Exception) {}
    }

    override fun onDestroy() {
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (e: Exception) {}
        scheduler?.shutdownNow()
        super.onDestroy()
    }
}
