import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/alexa/alexa_link.dart';
import 'package:nag_alarm/core/models.dart';

void main() {
  final now = DateTime(2026, 9, 25, 8, 0);
  NagTask task(String id, Duration fromNow,
          {TaskStatus status = TaskStatus.scheduled, String? title}) =>
      NagTask(
          id: id,
          title: title ?? id,
          dueAt: now.add(fromNow),
          status: status,
          updatedAt: now);

  test('sends open tasks, soonest first, in phone-local wall-clock time', () {
    final p = AlexaLink.payload([
      task('later', const Duration(hours: 5)),
      task('soon', const Duration(minutes: 30)),
      task('ringing', -const Duration(minutes: 3), status: TaskStatus.ringing),
      task('done', const Duration(hours: 1), status: TaskStatus.done),
      task('next-month', const Duration(days: 30)),
    ], now);

    expect(p.map((t) => t['id']), ['ringing', 'soon', 'later'],
        reason: 'done tasks stop the Echo; far-off ones wait');
    expect(p[1]['at'], '2026-09-25T08:30:00');
    expect(p[1]['everyMin'], AlexaLink.repeatEveryMinutes);
    expect(p[1]['count'], AlexaLink.repeatCount);
  });

  test('keeps the message small', () {
    final p = AlexaLink.payload([
      for (var i = 0; i < 40; i++)
        task('t$i', Duration(minutes: i), title: 'x' * 200),
    ], now);
    expect(p, hasLength(AlexaLink.maxTasks));
    expect((p.first['title'] as String).length, 60);
  });
}
