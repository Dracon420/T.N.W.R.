import 'models.dart';

/// What the alarm should sound like at a given moment.
class EscalationState {
  final double volume;
  final AlarmSound sound;
  const EscalationState(this.volume, this.sound);
}

/// Every snooze makes the next ring start this many steps louder.
const snoozePenaltySteps = 2;

EscalationState escalationAt(
  EscalationPolicy p,
  Duration ringingFor, {
  int snoozesUsed = 0,
}) {
  final secs = ringingFor.isNegative ? 0 : ringingFor.inSeconds;
  final steps = secs ~/ p.stepSeconds + snoozesUsed * snoozePenaltySteps;
  final volume = (p.startVolume + steps * p.stepSize).clamp(0.0, p.maxVolume);
  final sound = secs >= p.sirenAfterSeconds ? p.escalationSound : p.sound;
  return EscalationState(volume.toDouble(), sound);
}
