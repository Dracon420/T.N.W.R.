package com.nagalarm.nag_alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Alarm time reached, or the phone rebooted / the app was updated. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        when (intent.action) {
            AlarmScheduler.ACTION_FIRE -> intent.getStringExtra("id")?.let { AlarmService.fire(c, it) }

            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                AlarmScheduler.rescheduleAll(c)
                // Android doesn't allow starting the alarm service directly from
                // boot, so alarms that were ringing come back via an alarm-clock
                // alarm a few seconds from now.
                val ringing = AlarmStore.ringing(c)
                val soon = System.currentTimeMillis() + 3_000
                for (i in 0 until ringing.length()) {
                    AlarmScheduler.setAlarm(c, ringing.getJSONObject(i).getString("id"), soon)
                }
            }
        }
    }
}
