import 'package:flutter/widgets.dart';

import '../core/models.dart';
import 'math_challenge.dart';
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

ProofChallenge challengeFor(ProofSpec spec) => switch (spec) {
      MathProof() => MathChallenge(spec),
      TypingProof() => TypingChallenge(spec),
      QrProof() => const _NotYet('Scan QR code', 'Scan the tag you set up'),
      NfcProof() => const _NotYet('Tap NFC tag', 'Tap your phone on the tag'),
      LocationProof(:final label) =>
        _NotYet('Go to $label', 'Be at $label with your phone'),
      StepsProof(:final steps) =>
        _NotYet('Walk $steps steps', 'Walk with your phone in your pocket'),
      PhotoProof() =>
        const _NotYet('Take a photo', 'Photograph the finished task'),
    };

/// Human-readable label for the editor's proof picker.
String proofLabel(ProofSpec spec) => challengeFor(spec).title;

/// Placeholder for proof types that land in later build phases.
class _NotYet extends ProofChallenge {
  const _NotYet(this.title, this.description);

  @override
  final String title;
  @override
  final String description;
  @override
  bool get isSupportedHere => false;
  @override
  String get unsupportedHint => 'Not available in this beta build yet.';
  @override
  Widget build(VoidCallback onPassed) => const SizedBox.shrink();
}
