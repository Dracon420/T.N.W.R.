import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/settings.dart';

/// OS-level alarms that fire and ring with the app closed.
abstract class AlarmEngine {
  /// True when the engine plays the sound, escalates and pauses for calls
  /// itself, so the Dart ringer stays silent.
  bool get ownsRinging;

  /// Replaces all upcoming alarms with [scheduled].
  Future<void> sync(List<NagTask> scheduled, AppSettings settings);

  /// Makes sure [task] is ringing (it came due while the app was open).
  Future<void> ring(NagTask task);

  /// The task was proven or snoozed.
  Future<void> stop(String id);

  /// Silence [id] until [until] (waiting for a photo approval), then ring at
  /// the volume it had.
  Future<void> hold(String id, DateTime until);

  /// End a [hold] early (the approver said no).
  Future<void> releaseHold(String id);

  Future<bool> isPausedForCall();
}

/// Permissions and settings the phone needs for background alarms.
enum SetupItem {
  notifications('Allow notifications',
      'The alarm shows as a notification and opens over the lock screen.'),
  fullScreen('Allow full-screen alarms',
      'Lets the alarm fill the screen like an incoming call.'),
  exactAlarms('Allow alarms & reminders', 'Rings at the exact time you set.'),
  battery('Set battery to Unrestricted',
      "Stops the phone from putting T.N.W.R. to sleep and skipping alarms.");

  const SetupItem(this.title, this.why);
  final String title;
  final String why;
}

/// Android: lib side of AlarmScheduler / AlarmService (Kotlin).
class AndroidAlarmEngine implements AlarmEngine {
  static const _channel = MethodChannel('nag_alarm/alarms');

  @override
  bool get ownsRinging => true;

  @override
  Future<void> sync(List<NagTask> scheduled, AppSettings settings) =>
      _channel.invokeMethod('sync', jsonEncode({
        'alarms': [for (final t in scheduled) alarmJson(t)],
        'pauseDuringCalls': settings.pauseDuringCalls,
        'callResumeDelaySeconds': settings.callResumeDelaySeconds,
      }));

  @override
  Future<void> ring(NagTask task) => _channel.invokeMethod(
      'ring',
      jsonEncode({
        ...alarmJson(task),
        if (task.ringingSince != null)
          'since': task.ringingSince!.millisecondsSinceEpoch,
      }));

  @override
  Future<void> stop(String id) => _channel.invokeMethod('stop', id);

  @override
  Future<void> hold(String id, DateTime until) => _channel.invokeMethod(
      'hold', {'id': id, 'until': until.millisecondsSinceEpoch});

  @override
  Future<void> releaseHold(String id) =>
      _channel.invokeMethod('hold', {'id': id, 'until': 0});

  @override
  Future<bool> isPausedForCall() async =>
      await _channel.invokeMethod<bool>('isPausedForCall') ?? false;

  /// Missing items; empty when the phone is fully set up.
  Future<Set<SetupItem>> missingSetup() async {
    final status = await _channel.invokeMapMethod<String, bool>('setupStatus');
    return {
      for (final item in SetupItem.values)
        if (status?[item.name] == false) item
    };
  }

  /// Opens the permission prompt or settings page for [item].
  Future<void> fixSetup(SetupItem item) =>
      _channel.invokeMethod('fixSetup', item.name);

  /// Shape read by AlarmStore.kt.
  static Map<String, dynamic> alarmJson(NagTask t) => {
        'id': t.id,
        'title': t.title,
        'dueAt': t.dueAt.millisecondsSinceEpoch,
        'snoozesUsed': t.snoozesUsed,
        'esc': {
          'startVolume': t.escalation.startVolume,
          'stepSize': t.escalation.stepSize,
          'stepSeconds': t.escalation.stepSeconds,
          'maxVolume': t.escalation.maxVolume,
          'sound': t.escalation.sound.file,
          'escalationSound': t.escalation.escalationSound.file,
          'sirenAfterSeconds': t.escalation.sirenAfterSeconds,
          'vibrate': t.escalation.vibrate,
        },
      };
}
