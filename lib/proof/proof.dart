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

/// [taskTitle] is used by proofs that tell someone else about the task.
ProofChallenge challengeFor(ProofSpec spec, {String taskTitle = ''}) =>
    switch (spec) {
      MathProof() => MathChallenge(spec),
      TypingProof() => TypingChallenge(spec),
      QrProof() => ScanChallenge(spec),
      NfcProof() => NfcChallenge(spec),
      LocationProof() => LocationChallenge(spec),
      StepsProof() => StepsChallenge(spec),
      PhotoProof() => PhotoChallenge(spec),
      ApprovalProof() => ApprovalChallenge(spec, taskTitle: taskTitle),
    };

/// Human-readable label for the editor's proof picker.
String proofLabel(ProofSpec spec) => challengeFor(spec).title;
