import 'dart:async';

import 'package:flutter/foundation.dart';

import 'alarm/ringer.dart';
import 'core/escalation.dart';
import 'core/models.dart';
import 'core/schedule.dart';
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
class AppController extends ChangeNotifier {
  AppController(this.store, this.ringer, {this.surface});

  final TaskStore store;
  final Ringer ringer;
  final AlarmSurface? surface;

  Timer? _ticker;
  bool _ticking = false;
  EscalationState? current;

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
      final now = DateTime.now();
      for (final t in store.tasks) {
        if (t.status == TaskStatus.scheduled && !t.dueAt.isAfter(now)) {
          await store.upsert(t.copyWith(
              status: TaskStatus.ringing, ringingSince: () => now));
        }
      }

      final ringing = ringingTask;
      if (ringing != null) {
        if (!ringer.isRinging) await surface?.onRinging();
        current = escalationAt(
            ringing.escalation, now.difference(ringing.ringingSince!),
            snoozesUsed: ringing.snoozesUsed);
        await ringer.apply(current!);
        notifyListeners();
      } else if (ringer.isRinging) {
        current = null;
        await ringer.stop();
        await surface?.onQuiet();
        notifyListeners();
      }
    } finally {
      _ticking = false;
    }
  }

  bool canSnooze(NagTask t) => t.snoozesUsed < t.escalation.maxSnoozes;

  Future<void> snooze(NagTask t) async {
    if (!canSnooze(t)) return;
    await store.upsert(t.copyWith(
      status: TaskStatus.scheduled,
      dueAt: DateTime.now().add(Duration(minutes: t.escalation.snoozeMinutes)),
      ringingSince: () => null,
      snoozesUsed: t.snoozesUsed + 1,
    ));
    await tick();
  }

  /// Called once the task's proofs are satisfied.
  Future<void> complete(NagTask t) async {
    final now = DateTime.now();
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
        dueAt: DateTime.now().add(const Duration(seconds: 5)),
        ringingSince: () => null,
      ));

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
