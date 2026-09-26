package com.nagalarm.nag_alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import org.json.JSONObject
import java.io.File
import kotlin.math.roundToInt

/**
 * Rings with the app closed: plays on the alarm stream, escalates the alarm
 * volume once a second, and goes quiet during phone and video calls. Mirrors
 * lib/core/escalation.dart and AppController's call handling. It stops when
 * Dart removes the alarm from the ringing list after the proof is passed.
 */
class AlarmService : Service() {
    companion object {
        private const val TAG = "TNWR"
        private const val STATUS_ID = 7301
        private const val ALERT_ID = 7302
        private const val STATUS_CHANNEL = "alarm_status"
        private const val ALERT_CHANNEL = "alarms"

        /** Every snooze makes the next ring start this many steps louder. */
        private const val SNOOZE_PENALTY_STEPS = 2

        @Volatile var running = false
        @Volatile var pausedForCall = false

        /** An alarm-clock alarm fired for [id]. */
        fun fire(c: Context, id: String) {
            AlarmStore.findScheduled(c, id)?.let {
                AlarmStore.removeScheduled(c, id)
                AlarmStore.addRinging(c, it)
            }
            if (AlarmStore.isRinging(c, id)) start(c)
        }

        /** Dart saw [alarm] come due; make sure it's ringing. Idempotent. */
        fun ring(c: Context, alarm: JSONObject) {
            if (AlarmStore.addRinging(c, alarm)) AlarmStore.removeScheduled(c, alarm.getString("id"))
            if (!running) start(c)
        }

        /**
         * Silent until [untilMillis] while a photo approval is pending; 0 ends it.
         * Afterwards it rings at the volume it had (silent time doesn't count).
         */
        fun hold(c: Context, id: String, untilMillis: Long) {
            val alarm = AlarmStore.findRinging(c, id) ?: return
            alarm.put("holdUntil", untilMillis)
            AlarmStore.updateRinging(c, alarm)
        }

        /** The task was proven or snoozed. The service stops on its next tick if nothing else rings. */
        fun stop(c: Context, id: String): Int = AlarmStore.removeRinging(c, id)

        private fun start(c: Context) {
            val intent = Intent(c, AlarmService::class.java)
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(intent) else c.startService(intent)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val audio by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }
    private val notifications by lazy { getSystemService(NOTIFICATION_SERVICE) as NotificationManager }
    private var wakeLock: PowerManager.WakeLock? = null

    private var player: MediaPlayer? = null
    private var playingFile: String? = null
    private var currentId: String? = null
    private var volumeBefore: Int? = null
    private var forceVolume = true
    private var pausedAt = 0L
    private var callEndedAt: Long? = null
    private var alertShown = false
    private var held = false
    private var heldAt = 0L
    private var vibrating = false
    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= 31) {
            (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION") getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
    }

    private val ticker = object : Runnable {
        override fun run() {
            try {
                tick()
            } catch (e: Exception) {
                Log.e(TAG, "alarm tick failed", e)
            }
            if (running) handler.postDelayed(this, 1_000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannels()
        val first = AlarmStore.ringing(this).optJSONObject(0)
        val status = statusNotification(first?.optString("title") ?: "Reminder", paused = false)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(STATUS_ID, status, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(STATUS_ID, status)
        }
        if (!running) {
            running = true
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tnwr:alarm")
                .apply { acquire(60 * 60 * 1000L) }
            handler.post(ticker)
        }
        // If Android kills the service, it restarts it and the ringing list resumes.
        return START_STICKY
    }

    private fun tick() {
        val ringing = AlarmStore.ringing(this)
        if (ringing.length() == 0) {
            finish()
            return
        }
        val alarm = ringing.getJSONObject(0)
        val id = alarm.getString("id")
        if (id != currentId) {
            currentId = id
            forceVolume = true
            alertShown = false
        }
        val settings = AlarmStore.schedule(this)
        val now = System.currentTimeMillis()

        // Waiting for a photo approval: quiet until the verdict or the wait ends.
        if (alarm.optLong("holdUntil") > now) {
            if (!held) {
                if (pausedForCall) {
                    // End the call pause here so its time isn't counted twice.
                    alarm.put("pausedMs", alarm.optLong("pausedMs") + (now - pausedAt))
                    pausedForCall = false
                    callEndedAt = null
                }
                held = true
                heldAt = now
                AlarmStore.updateRinging(this, alarm)
                stopSound()
                stopVibration()
                restoreVolume()
                notifications.cancel(ALERT_ID)
                alertShown = false
                notifications.notify(STATUS_ID, statusNotification(alarm.optString("title"),
                    paused = false, waiting = true))
            }
            return
        }
        if (held) {
            alarm.put("pausedMs", alarm.optLong("pausedMs") + (now - heldAt))
            alarm.remove("holdUntil")
            AlarmStore.updateRinging(this, alarm)
            held = false
            notifications.notify(STATUS_ID, statusNotification(alarm.optString("title"), paused = false))
        }

        val inCall = settings.optBoolean("pauseDuringCalls", true) &&
            audio.mode != AudioManager.MODE_NORMAL
        if (inCall) {
            callEndedAt = null
            if (!pausedForCall) {
                pausedForCall = true
                pausedAt = now
                stopSound()
                stopVibration()
                restoreVolume()
                // Never pop the full-screen alarm over a call.
                notifications.cancel(ALERT_ID)
                alertShown = false
                notifications.notify(STATUS_ID, statusNotification(alarm.optString("title"), paused = true))
            }
            return
        }
        if (pausedForCall) {
            val ended = callEndedAt ?: now.also { callEndedAt = it }
            if (now - ended < settings.optInt("callResumeDelaySeconds", 30) * 1000L) return
            // Resume at the loudness it had before: call time doesn't count.
            alarm.put("pausedMs", alarm.optLong("pausedMs") + (now - pausedAt))
            AlarmStore.updateRinging(this, alarm)
            pausedForCall = false
            callEndedAt = null
            notifications.notify(STATUS_ID, statusNotification(alarm.optString("title"), paused = false))
        }
        if (!alertShown) {
            notifications.notify(ALERT_ID, alertNotification(alarm.optString("title")))
            alertShown = true
        }

        val esc = alarm.getJSONObject("esc")
        val elapsed = ((now - alarm.getLong("since") - alarm.optLong("pausedMs")) / 1000)
            .coerceAtLeast(0)
        val steps = elapsed / esc.getInt("stepSeconds") +
            alarm.optInt("snoozesUsed") * SNOOZE_PENALTY_STEPS
        val volume = (esc.getDouble("startVolume") + steps * esc.getDouble("stepSize"))
            .coerceIn(0.0, esc.getDouble("maxVolume"))
        val file = if (elapsed >= esc.getInt("sirenAfterSeconds")) {
            esc.getString("escalationSound")
        } else {
            esc.getString("sound")
        }
        if (file != playingFile) play(file)
        applyVolume(volume)
        if (esc.optBoolean("vibrate", true)) startVibration() else stopVibration()
    }

    /** Buzz 0.8 s, pause 0.6 s, repeat. Alarm usage, so silent mode doesn't stop it. */
    private fun startVibration() {
        if (vibrating || !vibrator.hasVibrator()) return
        vibrating = true
        val pattern = longArrayOf(0, 800, 600)
        if (Build.VERSION.SDK_INT < 26) {
            @Suppress("DEPRECATION") vibrator.vibrate(pattern, 0)
            return
        }
        val effect = VibrationEffect.createWaveform(pattern, 0)
        when {
            Build.VERSION.SDK_INT >= 33 -> vibrator.vibrate(effect,
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
            else -> @Suppress("DEPRECATION") vibrator.vibrate(effect,
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
        }
    }

    private fun stopVibration() {
        if (vibrating) vibrator.cancel()
        vibrating = false
    }

    /**
     * Sets the exact level when (re)starting so the alarm really starts soft;
     * after that it only goes up. The user may raise it, never lower it.
     */
    private fun applyVolume(level: Double) {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        val target = (level * max).roundToInt().coerceIn(1, max)
        val current = audio.getStreamVolume(AudioManager.STREAM_ALARM)
        if (volumeBefore == null) volumeBefore = current
        if (forceVolume || current < target) {
            try {
                audio.setStreamVolume(AudioManager.STREAM_ALARM, target, 0)
            } catch (e: SecurityException) {
                Log.w(TAG, "volume change blocked", e)
            }
            forceVolume = false
        }
    }

    private fun restoreVolume() {
        volumeBefore?.let {
            try {
                audio.setStreamVolume(AudioManager.STREAM_ALARM, it, 0)
            } catch (e: SecurityException) {
                Log.w(TAG, "volume restore blocked", e)
            }
        }
        volumeBefore = null
        forceVolume = true
    }

    private fun play(file: String) {
        stopSound()
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        player = try {
            // Flutter assets live in the APK; copy out so MediaPlayer can read it.
            val out = File(cacheDir, file)
            assets.open("flutter_assets/assets/sounds/$file").use { input ->
                out.outputStream().use { input.copyTo(it) }
            }
            MediaPlayer().apply {
                setAudioAttributes(attributes)
                setDataSource(out.path)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "couldn't play $file, using the system alarm sound", e)
            MediaPlayer().apply {
                setAudioAttributes(attributes)
                setDataSource(this@AlarmService,
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                isLooping = true
                prepare()
                start()
            }
        }
        playingFile = file
    }

    private fun stopSound() {
        player?.run {
            stop()
            release()
        }
        player = null
        playingFile = null
    }

    private fun finish() {
        running = false
        pausedForCall = false
        handler.removeCallbacks(ticker)
        stopSound()
        stopVibration()
        restoreVolume()
        notifications.cancel(ALERT_ID)
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        if (running) finish()
        super.onDestroy()
    }

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this, 1,
        Intent(this, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_FROM_ALARM, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    /** Quiet, ongoing notification required for a foreground service. */
    private fun statusNotification(title: String, paused: Boolean, waiting: Boolean = false): Notification =
        builder(STATUS_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(when {
                waiting -> "Quiet while your photo is checked. Rings again if there's no answer."
                paused -> "Paused for your call. Comes back after it ends."
                else -> "Ringing until you prove it's done"
            })
            .setOngoing(true)
            .setContentIntent(openAppIntent())
            .build()

    /** Pops the alarm screen over the lock screen, like an incoming call. */
    private fun alertNotification(title: String): Notification =
        builder(ALERT_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText("Tap to prove it's done")
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(openAppIntent())
            .setFullScreenIntent(openAppIntent(), true)
            .build()

    private fun builder(channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_MAX)
        }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        notifications.createNotificationChannel(
            NotificationChannel(ALERT_CHANNEL, "Ringing alarms", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Shows the alarm screen when a reminder goes off"
                setSound(null, null) // The service plays the alarm sound itself.
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            })
        notifications.createNotificationChannel(
            NotificationChannel(STATUS_CHANNEL, "Alarm status", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shown while an alarm is ringing or paused for a call"
                setSound(null, null)
            })
    }
}
