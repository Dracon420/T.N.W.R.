import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/app_controller.dart';
import 'package:nag_alarm/core/models.dart';
import 'package:nag_alarm/core/settings.dart';
import 'package:nag_alarm/core/task_store.dart';

import 'call_pause_test.dart' show FakeCalls, FakeRinger;
import 'engine_test.dart' show FakeEngine;

void main() {
  late Directory dir;
  late DateTime now;
  late FakeRinger ringer;
  late TaskStore store;
  late AppSettings settings;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tnwr_hold');
    now = DateTime(2026, 9, 25, 8);
    ringer = FakeRinger();
    store = TaskStore(File('${dir.path}/tasks.json'));
    settings = AppSettings(File('${dir.path}/settings.json'));
    await store.upsert(NagTask(
      id: 't',
      title: 'Dishes',
      dueAt: now,
      // +10% every 10 s from 30%.
      escalation: const EscalationPolicy(startVolume: 0.3, stepSize: 0.1, stepSeconds: 10),
      updatedAt: now,
    ));
  });

  tearDown(() => dir.delete(recursive: true));

  AppController controllerWith({FakeEngine? engine}) => AppController(store, ringer,
      settings: settings, calls: FakeCalls(), engine: engine, clock: () => now);

  Future<void> at(AppController c, int secondsIn) async {
    now = DateTime(2026, 9, 25, 8).add(Duration(seconds: secondsIn));
    await c.tick();
  }

  test('silent while waiting, then rings again at the volume it had', () async {
    final c = controllerWith();
    await at(c, 0); // Starts ringing.
    await at(c, 25);
    expect(ringer.playing?.volume, closeTo(0.5, 1e-9));

    await c.holdForApproval(store.byId('t')!, const Duration(minutes: 5));
    expect(ringer.isRinging, isFalse);
    await at(c, 25 + 4 * 60);
    expect(ringer.isRinging, isFalse);
    expect(c.approvalWaitLeft, const Duration(minutes: 1));

    await at(c, 25 + 5 * 60); // No answer in 5 minutes.
    expect(c.waitingForApproval, isFalse);
    expect(ringer.playing?.volume, closeTo(0.5, 1e-9),
        reason: 'same as before, not louder from the wait');
  });

  test('"not done" brings it back right away at the same volume', () async {
    final c = controllerWith();
    await at(c, 0); // Starts ringing.
    await at(c, 25);
    await c.holdForApproval(store.byId('t')!, const Duration(minutes: 20));
    await at(c, 90);
    await c.releaseApprovalHold();
    await at(c, 91);
    expect(ringer.playing?.volume, closeTo(0.5, 1e-9));
  });

  test('approval during the wait ends it for good', () async {
    final c = controllerWith();
    await at(c, 5);
    await c.holdForApproval(store.byId('t')!, const Duration(minutes: 10));
    await c.complete(store.byId('t')!);
    await at(c, 30);
    expect(c.waitingForApproval, isFalse);
    expect(ringer.isRinging, isFalse);
    expect(store.byId('t')!.status, TaskStatus.done);
  });

  test('on Android the background engine is told to hold and release', () async {
    final engine = FakeEngine();
    final c = controllerWith(engine: engine);
    await at(c, 5);
    await c.holdForApproval(store.byId('t')!, const Duration(minutes: 3));
    expect(engine.holds['t'], now.add(const Duration(minutes: 3)));
    await c.releaseApprovalHold();
    expect(engine.holds, isEmpty);
  });
}
