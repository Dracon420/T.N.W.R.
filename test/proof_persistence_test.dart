import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/app_controller.dart';
import 'package:nag_alarm/core/models.dart';
import 'package:nag_alarm/core/settings.dart';
import 'package:nag_alarm/core/task_store.dart';

import 'call_pause_test.dart' show FakeCalls, FakeRinger;

void main() {
  late Directory dir;
  final now = DateTime(2026, 9, 26, 16);

  setUp(() async => dir = await Directory.systemTemp.createTemp('tnwr_persist'));
  tearDown(() => dir.delete(recursive: true));

  /// A fresh app start: new store read from disk, new controller.
  Future<AppController> launch() async {
    final store = TaskStore(File('${dir.path}/tasks.json'));
    await store.load();
    return AppController(store, FakeRinger(),
        settings: AppSettings(File('${dir.path}/settings.json')),
        calls: FakeCalls(),
        clock: () => now);
  }

  Future<void> addRinging(AppController c, ProofMode mode) async {
    await c.store.upsert(NagTask(
      id: 't',
      title: 'Dishes',
      dueAt: now,
      proofs: const [MathProof(), ApprovalProof(approverName: 'Sam')],
      proofMode: mode,
      updatedAt: now,
    ));
    await c.tick();
  }

  test('a passed proof survives the app being closed (needs all)', () async {
    var c = await launch();
    await addRinging(c, ProofMode.all);
    await c.savePendingApproval(c.store.byId('t')!, 'req-1', 'https://x');
    await c.proofPassed(c.store.byId('t')!, 1); // Photo approved.

    c = await launch(); // Android closed the app.
    var t = c.store.byId('t')!;
    expect(t.status, TaskStatus.ringing);
    expect(t.passedProofs, [1], reason: 'the approval must not be lost');

    await c.proofPassed(t, 0); // Math.
    t = c.store.byId('t')!;
    expect(t.status, TaskStatus.done);
    expect(t.passedProofs, isEmpty, reason: 'cleared for the next ring');
    expect(t.pendingApprovalId, isNull);
  });

  test('a pending approval request survives the app being closed', () async {
    var c = await launch();
    await addRinging(c, ProofMode.all);
    await c.savePendingApproval(c.store.byId('t')!, 'req-1', 'https://x/a');
    c = await launch();
    expect(c.store.byId('t')!.pendingApprovalId, 'req-1');
    expect(c.store.byId('t')!.pendingApprovalUrl, 'https://x/a');
  });

  test('"any one" completes after a single proof', () async {
    final c = await launch();
    await addRinging(c, ProofMode.any);
    await c.proofPassed(c.store.byId('t')!, 1);
    expect(c.store.byId('t')!.status, TaskStatus.done);
  });

  test('a new ring starts with no proofs passed', () async {
    final c = await launch();
    await addRinging(c, ProofMode.all);
    await c.proofPassed(c.store.byId('t')!, 1);
    await c.snooze(c.store.byId('t')!);
    expect(c.store.byId('t')!.passedProofs, isEmpty);
  });
}
