package com.nagalarm.nag_alarm

import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nag_alarm/calls")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isInCall" -> result.success(isInCall())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * True during a phone call, while a call is ringing, and during voice/video
     * chats (WhatsApp, Meet, Messenger, ...): all of them switch the audio mode
     * away from normal. Needs no permission, unlike reading the phone state.
     */
    private fun isInCall(): Boolean {
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        return audio.mode != AudioManager.MODE_NORMAL
    }
}
