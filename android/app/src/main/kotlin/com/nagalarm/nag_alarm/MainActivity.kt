package com.nagalarm.nag_alarm

import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val audio by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }

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
    }

    /**
     * True during a phone call, while a call is ringing, and during voice/video
     * chats (WhatsApp, Meet, Messenger, ...): all of them switch the audio mode
     * away from normal. Needs no permission, unlike reading the phone state.
     */
    private fun isInCall(): Boolean = audio.mode != AudioManager.MODE_NORMAL
}
