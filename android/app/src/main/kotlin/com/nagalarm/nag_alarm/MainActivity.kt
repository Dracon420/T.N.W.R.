package com.nagalarm.nag_alarm

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_FROM_ALARM = "fromAlarm"
    }

    private val audio by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreenIfAlarm(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showOverLockScreenIfAlarm(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "nag_alarm/calls").setMethodCallHandler { call, result ->
            when (call.method) {
                "isInCall" -> result.success(isInCall())
                else -> result.notImplemented()
            }
        }

        // The alarm plays on the alarm stream, which silent/vibrate mode doesn't
        // mute; this reads and raises that stream's volume (no permission needed).
        MethodChannel(messenger, "nag_alarm/volume").setMethodCallHandler { call, result ->
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            when (call.method) {
                "get" -> result.success(
                    audio.getStreamVolume(AudioManager.STREAM_ALARM).toDouble() / max)
                "set" -> {
                    val level = (call.arguments as? Double)
                    if (level == null) {
                        result.error("BAD_ARGS", "Expected a double between 0 and 1", null)
                    } else {
                        try {
                            val index = (level.coerceIn(0.0, 1.0) * max).roundToInt()
                            audio.setStreamVolume(AudioManager.STREAM_ALARM, index, 0)
                            result.success(null)
                        } catch (e: SecurityException) {
                            // Some Do Not Disturb setups block volume changes.
                            result.error("DENIED", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Background alarms: see AlarmScheduler / AlarmService.
        MethodChannel(messenger, "nag_alarm/alarms").setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    AlarmScheduler.sync(this, JSONObject(call.arguments as String))
                    result.success(null)
                }
                "ring" -> {
                    AlarmService.ring(this, JSONObject(call.arguments as String))
                    result.success(null)
                }
                "stop" -> {
                    val left = AlarmService.stop(this, call.arguments as String)
                    if (left == 0) setShowOverLockScreen(false)
                    result.success(null)
                }
                "isPausedForCall" -> result.success(AlarmService.pausedForCall)
                "setupStatus" -> result.success(setupStatus())
                "fixSetup" -> {
                    fixSetup(call.arguments as String)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * True during a phone call, while a call is ringing, and during voice/video
     * chats (WhatsApp, Meet, Messenger, ...): all of them switch the audio mode
     * away from normal. Needs no permission, unlike reading the phone state.
     */
    private fun isInCall(): Boolean = audio.mode != AudioManager.MODE_NORMAL

    private fun showOverLockScreenIfAlarm(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_FROM_ALARM, false) == true) setShowOverLockScreen(true)
    }

    /** Only while an alarm rings; normal use keeps the lock screen. */
    private fun setShowOverLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    /** What still has to be allowed for alarms to ring with the app closed. */
    private fun setupStatus(): Map<String, Boolean> {
        val nm = getSystemService(NotificationManager::class.java)
        val notifications = nm.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
        val fullScreen = Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()
        val exactAlarms = Build.VERSION.SDK_INT < 31 ||
            getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
        val battery = getSystemService(PowerManager::class.java)
            .isIgnoringBatteryOptimizations(packageName)
        return mapOf(
            "notifications" to notifications,
            "fullScreen" to fullScreen,
            "exactAlarms" to exactAlarms,
            "battery" to battery,
        )
    }

    private fun fixSetup(item: String) {
        val pkg = Uri.parse("package:$packageName")
        when (item) {
            "notifications" -> {
                val prefs = getSharedPreferences("tnwr_setup", MODE_PRIVATE)
                if (Build.VERSION.SDK_INT >= 33 && !prefs.getBoolean("askedNotifications", false)) {
                    prefs.edit().putBoolean("askedNotifications", true).apply()
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                } else {
                    // Already asked once: Android only lets the user change it in Settings.
                    startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                }
            }
            "fullScreen" -> if (Build.VERSION.SDK_INT >= 34) {
                startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg))
            }
            "exactAlarms" -> if (Build.VERSION.SDK_INT >= 31) {
                startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg))
            }
            "battery" -> startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg))
        }
    }
}
