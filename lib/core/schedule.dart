import 'models.dart';

/// The next time a repeating task should ring after [previousDue], strictly
/// later than [now]. Returns null for one-off tasks.
///
/// Steps by calendar day (not 24h durations) so the time of day survives
/// daylight-saving changes.
DateTime? nextOccurrence(Repeat repeat, DateTime previousDue, DateTime now) {
  if (repeat.kind == RepeatKind.none) return null;

  final weekdays = repeat.kind == RepeatKind.weekly && repeat.weekdays.isNotEmpty
      ? repeat.weekdays.toSet()
      : null;

  var day = 1;
  while (true) {
    final candidate = DateTime(previousDue.year, previousDue.month,
        previousDue.day + day, previousDue.hour, previousDue.minute);
    day++;
    if (!candidate.isAfter(now)) continue;
    if (repeat.kind == RepeatKind.daily) return candidate;
    if ((weekdays ?? {previousDue.weekday}).contains(candidate.weekday)) {
      return candidate;
    }
  }
}

/// Whether the proofs passed so far are enough to switch the alarm off.
bool proofSatisfied(ProofMode mode, int totalProofs, int passedProofs) {
  if (totalProofs == 0) return true;
  return mode == ProofMode.all
      ? passedProofs >= totalProofs
      : passedProofs > 0;
}
