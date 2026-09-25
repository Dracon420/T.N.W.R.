import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/core/models.dart';
import 'package:nag_alarm/proof/photo_challenge.dart';
import 'package:nag_alarm/proof/proof.dart';

void main() {
  test('photo match is the share of reference labels seen again', () {
    const reference = ['Sink', 'Tableware', 'Countertop', 'Tap'];
    expect(photoMatch(reference, ['sink', 'Tap', 'Cat']), 0.5);
    expect(photoMatch(reference, ['Dog']), 0);
    expect(photoMatch(const [], ['Sink']), 0, reason: 'nothing to compare');
  });

  test('new proof settings survive saving', () {
    const proofs = <ProofSpec>[
      QrProof(code: '0123456789', label: 'medicine bottle'),
      NfcProof(tagId: '04:a2:1f', label: 'front door'),
      LocationProof(lat: 40.1, lng: -75.2, radiusMeters: 100, label: 'the gym'),
      StepsProof(steps: 500),
      PhotoProof(referencePath: '/x.jpg', referenceLabels: ['Sink', 'Tap']),
    ];
    for (final p in proofs) {
      expect(ProofSpec.fromJson(p.toJson()).toJson(), p.toJson());
    }
  });

  test('older saves without labels still load', () {
    expect((ProofSpec.fromJson({'type': 'qr', 'code': 'x'}) as QrProof).label, '');
    final photo = ProofSpec.fromJson(
        {'type': 'photo', 'referencePath': '/x.jpg', 'threshold': 0.75}) as PhotoProof;
    expect(photo.referenceLabels, isEmpty);
  });

  test('every proof type has a challenge with a title', () {
    const specs = <ProofSpec>[
      MathProof(),
      TypingProof(),
      QrProof(code: 'x'),
      NfcProof(tagId: 'x'),
      LocationProof(lat: 0, lng: 0, label: ''),
      StepsProof(),
      PhotoProof(referencePath: 'x'),
    ];
    for (final s in specs) {
      expect(challengeFor(s).title, isNotEmpty, reason: s.type);
    }
    expect(challengeFor(const LocationProof(lat: 0, lng: 0, label: '')).title,
        'Go to the saved spot');
  });
}
