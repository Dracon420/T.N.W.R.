import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/alarm/call_detector.dart';
import 'package:nag_alarm/alarm/ringer.dart';
import 'package:nag_alarm/app_controller.dart';
import 'package:nag_alarm/core/escalation.dart';
import 'package:nag_alarm/core/models.dart';
import 'package:nag_alarm/core/settings.dart';
import 'package:nag_alarm/core/task_store.dart';

class FakeRinger implements Ringer {
  EscalationState? playing;
  @override
  bool get isRinging => playing != null;
  @override
  Future<void> apply(EscalationState state) async => playing = state;
  @override
  Future<void> stop() async => playing = null;
}

class FakeCalls implements CallDetector {
  bool inCall = false;
  @override
  bool get isSupported => true;
  @override
  Future<bool> isInCall() async => inCall;
}

void main() {
  late Directory dir;
  late DateTime now;
  late FakeRinger ringer;
  late FakeCalls calls;
  late AppSettings settings;
  late AppController controller;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tnwr_test');
    now = DateTime(2026, 9, 25, 8, 0, 0);
    ringer = FakeRinger();
    calls = FakeCalls();
    settings = AppSettings(File('${dir.path}/settings.json'));
    final store = TaskStore(File('${dir.path}/tasks.json'));
    await store.upsert(NagTask(
      id: 't',
      title: 'Trash',
      dueAt: now,
      // +10% volume every 10 s from 30%.
      escalation: const EscalationPolicy(
          startVolume: 0.3, stepSize: 0.1, stepSeconds: 10),
      updatedAt: now,
    ));
    controller = AppController(store, ringer,
        settings: settings, calls: calls, clock: () => now);
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> at(int secondsIn) async {
    now = DateTime(2026, 9, 25, 8, 0, secondsIn);
    await controller.tick();
  }

  test('a call silences the alarm, which resumes at the same loudness',
      () async {
    await at(0);
    expect(ringer.playing?.volume, closeTo(0.3, 1e-9));
    await at(25);
    expect(ringer.playing?.volume, closeTo(0.5, 1e-9));

    calls.inCall = true; // Call starts at 25 s and lasts 5 minutes.
    await at(26);
    expect(ringer.isRinging, isFalse);
    expect(controller.pausedForCall, isTrue);
    await at(325);
    expect(ringer.isRinging, isFalse);

    calls.inCall = false; // Hangs up: 30 s grace by default.
    await at(326);
    await at(355);
    expect(ringer.isRinging, isFalse, reason: 'still in the grace period');

    await at(356);
    expect(controller.pausedForCall, isFalse);
    // Same 50% as before the call, not 100% from counting the call time.
    expect(ringer.playing?.volume, closeTo(0.5, 1e-9));
    expect(controller.ringingTask, isNotNull, reason: 'still must be proven');
  });

  test('an alarm that comes due during a call waits for it to end', () async {
    calls.inCall = true;
    await at(0);
    expect(ringer.isRinging, isFalse);
    expect(controller.ringingTask, isNotNull);

    calls.inCall = false;
    await settings.setCallResumeDelaySeconds(0);
    await at(120);
    expect(ringer.playing?.volume, closeTo(0.3, 1e-9),
        reason: 'starts from the beginning, not two minutes in');
  });

  test('pausing can be turned off in settings', () async {
    await settings.setPauseDuringCalls(false);
    calls.inCall = true;
    await at(0);
    expect(ringer.isRinging, isTrue);
  });
}
