import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/core/models.dart';
import 'package:nag_alarm/ui/task_edit_screen.dart';

void main() {
  testWidgets('sound pickers list every sound and save the choice',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    NagTask? saved;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => saved = await Navigator.of(context)
              .push<NagTask>(
                  MaterialPageRoute(builder: (_) => const TaskEditScreen())),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Starting sound'), findsOneWidget);
    expect(find.text('Escalation sound'), findsOneWidget);
    expect(find.text('Flash the screen'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Trash');
    await tester.tap(find.text('Classic beep · Loud'));
    await tester.pumpAndSettle();
    for (final s in AlarmSound.values) {
      expect(find.textContaining(s.label), findsWidgets, reason: s.label);
    }
    await tester.tap(find.textContaining('Low tone 520 Hz · Loud (').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flash the screen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved?.escalation.sound, AlarmSound.lowTone);
    expect(saved?.escalation.escalationSound, AlarmSound.siren);
    expect(saved?.escalation.flashScreen, isTrue);
  });

  testWidgets('"Any one" is saved when chosen', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    NagTask? saved;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => saved = await Navigator.of(context)
              .push<NagTask>(
                  MaterialPageRoute(builder: (_) => const TaskEditScreen())),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Dishes');
    await tester.tap(find.text('Any one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved?.proofMode, ProofMode.any);
  });
}
