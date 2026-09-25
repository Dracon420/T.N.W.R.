import 'dart:async';

import 'package:flutter/foundation.dart';

import 'alarm/call_detector.dart';
import 'alarm/ringer.dart';
import 'core/escalation.dart';
import 'core/models.dart';
import 'core/schedule.dart';
import 'core/settings.dart';
import 'core/task_store.dart';

/// Hooks the desktop shell (or later, a phone engine) uses to react when the
/// alarm starts and stops.
abstract class AlarmSurface {
  Future<void> onRinging();
  Future<void> onQuiet();
}

/// Ticks once a second: marks due tasks as ringing, escalates the ringer, and
/// applies snooze/complete. Ringing state is saved to disk, so killing and
/// relaunching the app keeps the alarm going where it left off.
///
/// While the user is on a call or video chat, a ringing alarm goes silent and
/// comes back after the call, at the same loudness it had before.
class AppController extends ChangeNotifier {
  AppController(
    this.store,
    this.ringer, {
    required this.settings,
    this.surface,
    CallDetector? calls,
    DateTime Function()? clock,
  })  : _calls = calls ?? CallDetector(),
        _now = clock ?? DateTime.now;

  final TaskStore store;
  final Ringer ringer;
  final AppSettings settings;
  final AlarmSurface? surface;
  final CallDetector _calls;
  final DateTime Function() _now;

  Timer? _ticker;
  bool _ticking = false;
  EscalationState? current;

  /// When the ringing alarm was silenced for a call; null when not paused.
  DateTime? _pausedAt;
  DateTime? _callEndedAt;

  bool get pausedForCall => _pausedAt != null;

  NagTask? get ringingTask {
    final ringing =
        store.tasks.where((t) => t.status == TaskStatus.ringing).toList()
          ..sort((a, b) => a.ringingSince!.compareTo(b.ringingSince!));
    return ringing.isEmpty ? null : ringing.first;
  }

  void start() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    tick();
  }

  @visibleForTesting
  Future<void> tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      final now = _now();
      for (final t in store.tasks) {
        if (t.status == TaskStatus.scheduled && !t.dueAt.isAfter(now)) {
          await store.upsert(t.copyWith(
              status: TaskStatus.ringing, ringingSince: () => now));
        }
      }

      var ringing = ringingTask;
      if (ringing == null) {
        _pausedAt = _callEndedAt = null;
        if (ringer.isRinging) await _silence();
        return;
      }

      if (await _holdForCall(ringing, now)) return;
      ringing = ringingTask!;

      if (!ringer.isRinging) await surface?.onRinging();
      current = escalationAt(
          ringing.escalation, now.difference(ringing.ringingSince!),
          snoozesUsed: ringing.snoozesUsed);
      await ringer.apply(current!);
      notifyListeners();
    } finally {
      _ticking = false;
    }
  }

  /// Returns true while the alarm should stay silent because of a call.
  Future<bool> _holdForCall(NagTask ringing, DateTime now) async {
    final inCall = settings.pauseDuringCalls && await _calls.isInCall();
    if (inCall) {
      _callEndedAt = null;
      if (_pausedAt == null) {
        _pausedAt = now;
        await _silence();
      }
      notifyListeners();
      return true;
    }
    if (_pausedAt == null) return false;

    _callEndedAt ??= now;
    final grace = Duration(seconds: settings.callResumeDelaySeconds);
    if (now.difference(_callEndedAt!) < grace) {
      notifyListeners();
      return true;
    }

    // Resume at the loudness it had before the call: time spent on the call
    // doesn't count toward escalation.
    final paused = now.difference(_pausedAt!);
    _pausedAt = _callEndedAt = null;
    await store.upsert(ringing.copyWith(
        ringingSince: () => ringing.ringingSince!.add(paused)));
    return false;
  }

  Future<void> _silence() async {
    current = null;
    await ringer.stop();
    await surface?.onQuiet();
    notifyListeners();
  }

  bool canSnooze(NagTask t) => t.snoozesUsed < t.escalation.maxSnoozes;

  Future<void> snooze(NagTask t) async {
    if (!canSnooze(t)) return;
    await store.upsert(t.copyWith(
      status: TaskStatus.scheduled,
      dueAt: _now().add(Duration(minutes: t.escalation.snoozeMinutes)),
      ringingSince: () => null,
      snoozesUsed: t.snoozesUsed + 1,
    ));
    await tick();
  }

  /// Called once the task's proofs are satisfied.
  Future<void> complete(NagTask t) async {
    final now = _now();
    final next = nextOccurrence(t.repeat, t.dueAt, now);
    await store.upsert(t.copyWith(
      status: next == null ? TaskStatus.done : TaskStatus.scheduled,
      dueAt: next,
      ringingSince: () => null,
      snoozesUsed: 0,
      completedAt: () => now,
    ));
    await tick();
  }

  /// Makes a task ring a few seconds from now, for trying out its settings.
  Future<void> testRing(NagTask t) => store.upsert(t.copyWith(
        status: TaskStatus.scheduled,
        dueAt: _now().add(const Duration(seconds: 5)),
        ringingSince: () => null,
      ));

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
