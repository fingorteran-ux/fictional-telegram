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
import android.os.IBinder
import android.os.PowerManager
import android.speech.tts.TextToSpeech
import androidx.core.app.NotificationCompat
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
    private val previousOnline = HashSet<String>()
    private var isFirstRun = true
    private var isSirenRunning = false
    private var sirenTrack: AudioTrack? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    companion object {
        const val ACTION_STOP_SIREN = "com.tactical.tibia.ACTION_STOP_SIREN"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale("es", "ES")
            ttsReady = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_SIREN) {
            stopSirenAndVoice()
            val notifyMgr = getSystemService(NotificationManager::class.java)
            notifyMgr?.cancel(9999)
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
                "radar_status",
                "Estado Spy Ferobra",
                NotificationManager.IMPORTANCE_LOW
            )
            manager?.createNotificationChannel(statusChannel)

            val alertChannel = NotificationChannel(
                "radar_alerts",
                "Alertas Tácticas de Emergencia",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Sirenas y avisos de voz"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 150, 250)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
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

        return NotificationCompat.Builder(this, "radar_status")
            .setContentTitle("🛰️ SPY FEROBRA // EN VIVO")
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
                scanWorld()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, 3, 35, TimeUnit.SECONDS)
    }

    private fun speakText(text: String) {
        try {
            if (ttsReady && tts != null) {
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "TTS_ALERT")
            }
        } catch (e: Exception) {}
    }

    private fun scanWorld() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val targetList = mutableSetOf<String>()

        val directTargets = prefs.getStringSet("direct_radar_targets", null)
        if (directTargets != null) {
            for (t in directTargets) targetList.add(t.trim().lowercase())
        }

        if (targetList.isEmpty()) return

        val url = URL("https://api.tibiadata.com/v4/world/Ferobra")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 12000
        conn.readTimeout = 12000
        conn.requestMethod = "GET"

        if (conn.responseCode == 200) {
            val reader = BufferedReader(InputStreamReader(conn.inputStream))
            val sb = StringBuilder()
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                sb.append(line)
            }
            reader.close()

            val json = JSONObject(sb.toString())
            val worldObj = json.optJSONObject("world") ?: return
            val playersArr = worldObj.optJSONArray("online_players") ?: return

            val currentOnlineMap = HashMap<String, String>()
            for (i in 0 until playersArr.length()) {
                val p = playersArr.getJSONObject(i)
                val name = p.optString("name").trim().lowercase()
                val lvl = p.optInt("level")
                val voc = p.optString("vocation")
                currentOnlineMap[name] = "$lvl - $voc"
            }

            if (!isFirstRun) {
                // LOGIN: Voz diciendo que conectó + pitidos
                for (target in targetList) {
                    if (currentOnlineMap.containsKey(target) && !previousOnline.contains(target)) {
                        val info = currentOnlineMap[target] ?: ""
                        speakText("Atención: $target, se conectó tu enemigo.")
                        showLoginNotification(target, info)
                    }
                }

                // LOGOUT: Voz diciendo que desconectó + SIRENA DE 5 SEGUNDOS
                for (target in targetList) {
                    if (!currentOnlineMap.containsKey(target) && previousOnline.contains(target)) {
                        speakText("Atención: $target, se desconectó tu enemigo.")
                        triggerFiveSecondSirenAlert(target)
                    }
                }
            } else {
                isFirstRun = false
            }

            previousOnline.clear()
            previousOnline.addAll(currentOnlineMap.keys)

            val onlineCount = targetList.count { currentOnlineMap.containsKey(it) }
            val notifyMgr = getSystemService(NotificationManager::class.java)
            notifyMgr?.notify(
                1001,
                createPersistentNotification("Vigilando Ferobra: $onlineCount/${targetList.size} enemigos activos")
            )
        }
    }

    private fun showLoginNotification(target: String, info: String) {
        wakeUpScreen()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, (System.currentTimeMillis() % 10000).toInt(), launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val builder = NotificationCompat.Builder(this, "radar_alerts")
            .setContentTitle("⚠️ [SPY FEROBRA: CONECTADO]")
            .setContentText("🎯 ${target.uppercase()} ($info) acaba de entrar!")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 150, 100, 150))

        val notifyMgr = getSystemService(NotificationManager::class.java)
        notifyMgr?.notify((System.currentTimeMillis() % 100000).toInt(), builder.build())
    }

    private fun triggerFiveSecondSirenAlert(target: String) {
        wakeUpScreen()
        startContinuousSirenAudio(5) // SIRENA DE 5 SEGUNDOS

        val stopIntent = Intent(this, RadarService::class.java).apply {
            action = ACTION_STOP_SIREN
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 202, stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        launchIntent?.action = ACTION_STOP_SIREN
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 303, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, "radar_alerts")
            .setContentTitle("🚨 ¡ENEMIGO DESCONECTADO! 🚨")
            .setContentText("💀 ${target.uppercase()} acaba de SALIR de Ferobra.")
            .setStyle(NotificationCompat.BigTextStyle().bigText("💀 ${target.uppercase()} salió de Ferobra.\nSirena de 5s. Toca para apagar."))
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openAppPendingIntent)
            .setDeleteIntent(stopPendingIntent)
            .setAutoCancel(true)
            .addAction(android.R.drawable.ic_lock_power_off, "SILENCIAR", stopPendingIntent)
            .build()

        val notifyMgr = getSystemService(NotificationManager::class.java)
        notifyMgr?.notify(9999, notification)
    }

    private fun startContinuousSirenAudio(seconds: Int) {
        stopSiren()
        isSirenRunning = true

        Thread {
            try {
                // Pausa corta para que la voz diga el nombre antes de sonar la sirena
                Thread.sleep(2200)
                if (!isSirenRunning) return@Thread

                val sampleRate = 22050
                val cycleDuration = 1.0
                val cycleSamples = (sampleRate * cycleDuration).toInt()
                val buffer = ShortArray(cycleSamples)
                var phase = 0.0

                for (i in 0 until cycleSamples) {
                    val t = i.toDouble() / sampleRate
                    val freq = 750.0 + 320.0 * Math.sin(2.0 * Math.PI * (1.0 / cycleDuration) * t)
                    phase += 2.0 * Math.PI * freq / sampleRate
                    buffer[i] = (Math.sin(phase) * 32767 * 0.95).toInt().toShort()
                }

                val minBuf = AudioTrack.getMinBufferSize(
                    sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT
                )

                val track = AudioTrack(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .build(),
                    maxOf(buffer.size * 2, minBuf),
                    AudioTrack.MODE_STREAM,
                    AudioManager.AUDIO_SESSION_ID_GENERATE
                )

                sirenTrack = track
                track.play()

                val endTime = System.currentTimeMillis() + (seconds * 1000)

                while (isSirenRunning && System.currentTimeMillis() < endTime) {
                    track.write(buffer, 0, buffer.size)
                }

                track.stop()
                track.release()
                sirenTrack = null
                isSirenRunning = false

                val notifyMgr = getSystemService(NotificationManager::class.java)
                notifyMgr?.cancel(9999)
            } catch (e: Exception) {}
        }.start()
    }

    private fun stopSiren() {
        isSirenRunning = false
        try {
            sirenTrack?.stop()
            sirenTrack?.release()
            sirenTrack = null
        } catch (e: Exception) {}
    }

    private fun stopSirenAndVoice() {
        stopSiren()
        try {
            tts?.stop()
        } catch (e: Exception) {}
    }

    private fun wakeUpScreen() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "spy_ferobra:siren_wake"
            )
            wl.acquire(8000)
        } catch (e: Exception) {}
    }

    override fun onDestroy() {
        stopSirenAndVoice()
        try {
            tts?.shutdown()
        } catch (e: Exception) {}
        scheduler?.shutdownNow()
        super.onDestroy()
    }
}
