import 'package:flutter/widgets.dart';

import '../core/models.dart';
import 'approval_challenge.dart';
import 'location_challenge.dart';
import 'math_challenge.dart';
import 'nfc_challenge.dart';
import 'photo_challenge.dart';
import 'scan_challenge.dart';
import 'steps_challenge.dart';
import 'typing_challenge.dart';

/// Runs one [ProofSpec] on this device. A challenge widget calls [onPassed]
/// once the user succeeds; failures are handled inside the widget (a new
/// problem, a reset counter, and so on).
abstract class ProofChallenge {
  const ProofChallenge();

  String get title;
  String get description;
  bool get isSupportedHere => true;

  /// Shown when this device can't run the challenge.
  String get unsupportedHint => '';

  Widget build(VoidCallback onPassed);
}

/// Lets a challenge quiet the alarm while it waits on someone else.
class AlarmHold {
  const AlarmHold(
      {required this.start, required this.release, this.pending, this.savePending});

  /// Silence the alarm for up to this long.
  final Future<void> Function(Duration wait) start;

  /// Ring again now, at the volume it had.
  final Future<void> Function() release;

  /// The saved approval request being waited on, if any.
  final ({String id, String url})? Function()? pending;

  /// Saves (or with nulls, clears) the approval request being waited on, so
  /// it survives Android closing the app.
  final Future<void> Function(String? id, String? url)? savePending;
}

/// [taskTitle] and [hold] are for proofs that involve someone else.
ProofChallenge challengeFor(ProofSpec spec,
        {String taskTitle = '', AlarmHold? hold}) =>
    switch (spec) {
      MathProof() => MathChallenge(spec),
      TypingProof() => TypingChallenge(spec),
      QrProof() => ScanChallenge(spec),
      NfcProof() => NfcChallenge(spec),
      LocationProof() => LocationChallenge(spec),
      StepsProof() => StepsChallenge(spec),
      PhotoProof() => PhotoChallenge(spec),
      ApprovalProof() =>
        ApprovalChallenge(spec, taskTitle: taskTitle, hold: hold),
    };

/// Human-readable label for the editor's proof picker.
String proofLabel(ProofSpec spec) => challengeFor(spec).title;
