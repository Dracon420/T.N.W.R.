package com.nagalarm.nag_alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

/**
 * Sets one AlarmManager alarm-clock alarm per upcoming reminder. Alarm-clock
 * alarms fire on time in Doze and battery saver, even with the app closed,
 * and are allowed to start the alarm service from the background.
 */
object AlarmScheduler {
    const val ACTION_FIRE = "com.nagalarm.nag_alarm.FIRE"

    fun sync(c: Context, schedule: JSONObject) {
        val am = c.getSystemService(AlarmManager::class.java)
        for (id in AlarmStore.scheduledIds(c)) {
            firePending(c, id, create = false)?.let { am.cancel(it) }
        }
        AlarmStore.saveSchedule(c, schedule)

        val alarms = schedule.getJSONArray("alarms")
        val ids = mutableSetOf<String>()
        for (i in 0 until alarms.length()) {
            val alarm = alarms.getJSONObject(i)
            val id = alarm.getString("id")
            if (AlarmStore.isRinging(c, id)) continue
            setAlarm(c, id, alarm.getLong("dueAt"))
            ids += id
        }
        AlarmStore.saveScheduledIds(c, ids)
    }

    /** After a reboot or app update, which clear all alarms. */
    fun rescheduleAll(c: Context) = sync(c, AlarmStore.schedule(c))

    fun setAlarm(c: Context, id: String, atMillis: Long) {
        val am = c.getSystemService(AlarmManager::class.java)
        val fire = firePending(c, id, create = true)!!
        if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
            // Exact alarms denied: still fire, possibly a few minutes late.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, fire)
            return
        }
        val show = PendingIntent.getActivity(
            c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        am.setAlarmClock(AlarmManager.AlarmClockInfo(atMillis, show), fire)
    }

    private fun firePending(c: Context, id: String, create: Boolean): PendingIntent? {
        val intent = Intent(c, AlarmReceiver::class.java).setAction(ACTION_FIRE).putExtra("id", id)
        val flags = PendingIntent.FLAG_IMMUTABLE or
            if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE
        return PendingIntent.getBroadcast(c, id.hashCode(), intent, flags)
    }
}
