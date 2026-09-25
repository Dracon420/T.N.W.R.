import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/alarm/ringer.dart';
import 'package:nag_alarm/alarm/system_volume.dart';
import 'package:nag_alarm/core/escalation.dart';
import 'package:nag_alarm/core/models.dart';

/// Stands in for the phone/PC volume.
class FakeVolume implements SystemVolume {
  FakeVolume(this.level);
  double level;
  @override
  bool get isSupported => true;
  @override
  Future<double> get() async => level;
  @override
  Future<void> set(double v) async => level = v;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts soft even if the volume was maxed, only goes up, then restores',
      () async {
    final volume = FakeVolume(1.0); // User's volume is at max.
    final ringer = Ringer(volume);

    await ringer.apply(const EscalationState(0.3, AlarmSound.beep));
    expect(volume.level, 0.3, reason: 'starts at the starting volume');

    volume.level = 0.1; // User turns it down...
    await ringer.apply(const EscalationState(0.3, AlarmSound.beep));
    expect(volume.level, 0.3, reason: '...and it goes straight back up');

    volume.level = 0.9; // User turns it up: allowed.
    await ringer.apply(const EscalationState(0.4, AlarmSound.beep));
    expect(volume.level, 0.9);

    await ringer.stop();
    expect(volume.level, 1.0, reason: "back to the user's own volume");
  });
}
