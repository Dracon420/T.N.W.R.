package com.nagalarm.nag_alarm

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Alarm data shared by the scheduler, receiver and service, so alarms work
 * while the Flutter app is closed. Dart writes it through MainActivity
 * ("sync" and "ring"); the native side reads it.
 *
 * An alarm is {id, title, dueAt (ms), snoozesUsed, esc: {startVolume,
 * stepSize, stepSeconds, maxVolume, sound, escalationSound,
 * sirenAfterSeconds}}; once ringing it also has since (ms) and pausedMs.
 */
object AlarmStore {
    private fun prefs(c: Context) = c.getSharedPreferences("tnwr_alarms", Context.MODE_PRIVATE)

    /** {"alarms": [...upcoming], "pauseDuringCalls": bool, "callResumeDelaySeconds": int} */
    fun schedule(c: Context): JSONObject =
        prefs(c).getString("schedule", null)?.let { JSONObject(it) }
            ?: JSONObject().put("alarms", JSONArray())

    fun saveSchedule(c: Context, schedule: JSONObject) {
        prefs(c).edit().putString("schedule", schedule.toString()).commit()
    }

    fun findScheduled(c: Context, id: String): JSONObject? {
        val alarms = schedule(c).getJSONArray("alarms")
        return (0 until alarms.length()).map { alarms.getJSONObject(it) }
            .firstOrNull { it.getString("id") == id }
    }

    fun removeScheduled(c: Context, id: String) {
        val s = schedule(c)
        s.put("alarms", s.getJSONArray("alarms").without(id))
        saveSchedule(c, s)
    }

    /** Ids with an AlarmManager alarm set, so they can be cancelled on the next sync. */
    fun scheduledIds(c: Context): Set<String> =
        prefs(c).getStringSet("scheduledIds", emptySet())!!.toSet()

    fun saveScheduledIds(c: Context, ids: Set<String>) {
        prefs(c).edit().putStringSet("scheduledIds", ids).commit()
    }

    /** Alarms ringing now, oldest first. */
    fun ringing(c: Context): JSONArray =
        prefs(c).getString("ringing", null)?.let { JSONArray(it) } ?: JSONArray()

    private fun saveRinging(c: Context, ringing: JSONArray) {
        prefs(c).edit().putString("ringing", ringing.toString()).commit()
    }

    fun isRinging(c: Context, id: String): Boolean = ringing(c).indexOf(id) >= 0

    /** Returns false if it was already ringing. */
    fun addRinging(c: Context, alarm: JSONObject): Boolean {
        val ringing = ringing(c)
        if (ringing.indexOf(alarm.getString("id")) >= 0) return false
        alarm.put("since", alarm.optLong("since", System.currentTimeMillis()))
        alarm.put("pausedMs", alarm.optLong("pausedMs", 0))
        ringing.put(alarm)
        saveRinging(c, ringing)
        return true
    }

    fun updateRinging(c: Context, alarm: JSONObject) {
        val ringing = ringing(c)
        val i = ringing.indexOf(alarm.getString("id"))
        if (i >= 0) {
            ringing.put(i, alarm)
            saveRinging(c, ringing)
        }
    }

    fun findRinging(c: Context, id: String): JSONObject? {
        val ringing = ringing(c)
        val i = ringing.indexOf(id)
        return if (i >= 0) ringing.getJSONObject(i) else null
    }

    /** Returns how many alarms are still ringing. */
    fun removeRinging(c: Context, id: String): Int {
        val kept = ringing(c).without(id)
        saveRinging(c, kept)
        return kept.length()
    }

    private fun JSONArray.indexOf(id: String): Int =
        (0 until length()).firstOrNull { getJSONObject(it).getString("id") == id } ?: -1

    private fun JSONArray.without(id: String): JSONArray {
        val out = JSONArray()
        for (i in 0 until length()) {
            val o = getJSONObject(i)
            if (o.getString("id") != id) out.put(o)
        }
        return out
    }
}
