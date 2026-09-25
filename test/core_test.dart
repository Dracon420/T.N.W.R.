import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/core/escalation.dart';
import 'package:nag_alarm/core/models.dart';
import 'package:nag_alarm/core/schedule.dart';
import 'package:nag_alarm/proof/math_challenge.dart';
import 'package:nag_alarm/proof/typing_challenge.dart';

void main() {
  group('escalationAt', () {
    const p = EscalationPolicy(
        startVolume: 0.3,
        stepSize: 0.1,
        stepSeconds: 20,
        sirenAfterSeconds: 60,
        escalationSound: AlarmSound.siren);

    test('starts at the starting volume, beeping', () {
      final s = escalationAt(p, Duration.zero);
      expect(s.volume, closeTo(0.3, 1e-9));
      expect(s.sound, AlarmSound.beep);
    });

    test('steps up every interval and switches to the siren', () {
      expect(escalationAt(p, const Duration(seconds: 19)).volume,
          closeTo(0.3, 1e-9));
      expect(escalationAt(p, const Duration(seconds: 40)).volume,
          closeTo(0.5, 1e-9));
      expect(escalationAt(p, const Duration(seconds: 60)).sound,
          AlarmSound.siren);
    });

    test('uses the chosen start and escalation sounds', () {
      const q = EscalationPolicy(
          sound: AlarmSound.lowTone,
          escalationSound: AlarmSound.blast,
          sirenAfterSeconds: 10);
      expect(escalationAt(q, const Duration(seconds: 9)).sound,
          AlarmSound.lowTone);
      expect(escalationAt(q, const Duration(seconds: 10)).sound,
          AlarmSound.blast);
    });

    test('older saves without sound fields still load', () {
      final j = const EscalationPolicy().toJson()
        ..remove('sound')
        ..remove('escalationSound')
        ..remove('flashScreen');
      final p = EscalationPolicy.fromJson(j);
      expect(p.sound, AlarmSound.beep);
      expect(p.escalationSound, AlarmSound.siren);
      expect(p.flashScreen, isFalse);
    });

    test('every sound has a generated file', () {
      for (final s in AlarmSound.values) {
        expect(File('assets/sounds/${s.file}').existsSync(), isTrue,
            reason: s.file);
      }
    });

    test('never exceeds max volume', () {
      expect(escalationAt(p, const Duration(hours: 1)).volume, 1.0);
    });

    test('each snooze makes the next ring start louder', () {
      expect(escalationAt(p, Duration.zero, snoozesUsed: 1).volume,
          closeTo(0.5, 1e-9));
    });
  });

  group('nextOccurrence', () {
    final due = DateTime(2026, 9, 24, 8, 30); // a Thursday

    test('one-off tasks have no next occurrence', () {
      expect(nextOccurrence(const Repeat(), due, due), isNull);
    });

    test('daily skips ahead past now, keeping the time of day', () {
      final now = DateTime(2026, 9, 27, 9, 0);
      expect(nextOccurrence(const Repeat(kind: RepeatKind.daily), due, now),
          DateTime(2026, 9, 28, 8, 30));
    });

    test('weekly lands on the next selected weekday', () {
      const r = Repeat(
          kind: RepeatKind.weekly,
          weekdays: [DateTime.monday, DateTime.friday]);
      expect(nextOccurrence(r, due, due), DateTime(2026, 9, 25, 8, 30));
      expect(nextOccurrence(r, DateTime(2026, 9, 25, 8, 30), due),
          DateTime(2026, 9, 28, 8, 30));
    });
  });

  test('proofSatisfied honors all/any', () {
    expect(proofSatisfied(ProofMode.all, 2, 1), isFalse);
    expect(proofSatisfied(ProofMode.all, 2, 2), isTrue);
    expect(proofSatisfied(ProofMode.any, 2, 1), isTrue);
    expect(proofSatisfied(ProofMode.any, 2, 0), isFalse);
  });

  test('math problems have correct answers at every difficulty', () {
    final rng = Random(42);
    for (var d = 1; d <= 3; d++) {
      for (var i = 0; i < 200; i++) {
        final p = generateProblem(d, rng);
        final expr = p.question.replaceAll('×', '*').replaceAll('−', '-');
        expect(_eval(expr), p.answer, reason: p.question);
      }
    }
  });

  test('typing ignores case and spacing but not wrong words', () {
    expect(phraseMatches('purple monkey', '  Purple   MONKEY '), isTrue);
    expect(phraseMatches('purple monkey', 'purple donkey'), isFalse);
  });

  test('tasks survive a JSON round trip', () {
    final t = NagTask(
      id: 'x',
      title: 'Take out trash',
      dueAt: DateTime(2026, 9, 24, 20),
      repeat: const Repeat(kind: RepeatKind.weekly, weekdays: [2, 5]),
      proofs: const [
        MathProof(problems: 4, difficulty: 3),
        TypingProof(words: 5),
        QrProof(code: 'abc'),
        LocationProof(lat: 1.5, lng: -2.5, label: 'Gym'),
      ],
      proofMode: ProofMode.any,
      status: TaskStatus.ringing,
      ringingSince: DateTime(2026, 9, 24, 20, 1),
      updatedAt: DateTime(2026, 9, 24),
    );
    final back = NagTask.fromJson(t.toJson());
    expect(back.toJson(), t.toJson());
  });
}

/// Tiny evaluator for "a op b op c" with * before + and -.
int _eval(String expr) {
  final tokens = expr.split(' ');
  final nums = <int>[int.parse(tokens[0])];
  final ops = <String>[];
  for (var i = 1; i < tokens.length; i += 2) {
    final n = int.parse(tokens[i + 1]);
    if (tokens[i] == '*') {
      nums.add(nums.removeLast() * n);
    } else {
      ops.add(tokens[i]);
      nums.add(n);
    }
  }
  var result = nums[0];
  for (var i = 0; i < ops.length; i++) {
    result = ops[i] == '+' ? result + nums[i + 1] : result - nums[i + 1];
  }
  return result;
}
