import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../alarm/alarm_player.dart';
import '../core/models.dart';

/// Create or edit a reminder. Pops with the saved [NagTask], or null.
class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key, this.task});

  final NagTask? task;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late final _title = TextEditingController(text: widget.task?.title);
  late final _notes = TextEditingController(text: widget.task?.notes);
  late DateTime _due = widget.task?.dueAt ??
      DateTime.now().add(const Duration(hours: 1)).copyWith(
          minute: 0, second: 0, millisecond: 0, microsecond: 0);
  late Repeat _repeat = widget.task?.repeat ?? const Repeat();
  late EscalationPolicy _esc =
      widget.task?.escalation ?? const EscalationPolicy();
  late ProofMode _mode = widget.task?.proofMode ?? ProofMode.all;
  late MathProof? _math = _find<MathProof>() ??
      (widget.task == null ? const MathProof() : null);
  late TypingProof? _typing = _find<TypingProof>();

  T? _find<T extends ProofSpec>() =>
      widget.task?.proofs.whereType<T>().firstOrNull;

  List<ProofSpec> get _proofs => [
        ?_math,
        ?_typing,
        // Kept as-is until their editors land in later phases.
        ...?widget.task?.proofs
            .where((p) => p is! MathProof && p is! TypingProof),
      ];

  @override
  void dispose() {
    SoundPreview.stop();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (time == null) return;
    setState(() => _due =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    if (_title.text.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Give the reminder a name.')));
      return;
    }
    if (_proofs.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Pick at least one way to prove it\'s done.')));
      return;
    }
    final now = DateTime.now();
    final base = widget.task ??
        NagTask(id: const Uuid().v4(), title: '', dueAt: _due, updatedAt: now);
    Navigator.of(context).pop(base.copyWith(
      title: _title.text.trim(),
      notes: _notes.text.trim(),
      dueAt: _due,
      repeat: _repeat,
      escalation: _esc,
      proofs: _proofs,
      proofMode: _mode,
      // Saving re-arms the task, including ones that were already done.
      status: TaskStatus.scheduled,
      ringingSince: () => null,
      snoozesUsed: 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Text(text, style: theme.textTheme.titleMedium),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New reminder' : 'Edit reminder'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: widget.task == null,
            decoration: const InputDecoration(
                labelText: 'What needs doing?', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Notes (optional)', border: OutlineInputBorder()),
          ),
          section('When'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(DateFormat('EEEE, MMM d · h:mm a').format(_due)),
            trailing: const Icon(Icons.edit),
            onTap: _pickDateTime,
          ),
          SegmentedButton<RepeatKind>(
            segments: const [
              ButtonSegment(value: RepeatKind.none, label: Text('Once')),
              ButtonSegment(value: RepeatKind.daily, label: Text('Daily')),
              ButtonSegment(value: RepeatKind.weekly, label: Text('Weekly')),
            ],
            selected: {_repeat.kind},
            onSelectionChanged: (s) => setState(() => _repeat = Repeat(
                kind: s.first,
                weekdays: s.first == RepeatKind.weekly ? [_due.weekday] : [])),
          ),
          if (_repeat.kind == RepeatKind.weekly)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                children: [
                  for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                    FilterChip(
                      label: Text(const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d - 1]),
                      selected: _repeat.weekdays.contains(d),
                      onSelected: (on) => setState(() => _repeat = Repeat(
                            kind: RepeatKind.weekly,
                            weekdays: on
                                ? [..._repeat.weekdays, d]
                                : (_repeat.weekdays.toList()..remove(d)),
                          )),
                    ),
                ],
              ),
            ),
          section('How annoying'),
          _slider('Starting volume', _esc.startVolume, 0.05, 1,
              '${(_esc.startVolume * 100).round()}%',
              (v) => _esc = _esc.copyWith(startVolume: v)),
          _slider('Gets louder every', _esc.stepSeconds.toDouble(), 5, 120,
              '${_esc.stepSeconds}s',
              (v) => _esc = _esc.copyWith(stepSeconds: v.round()),
              divisions: 23),
          _soundPicker('Starting sound', _esc.sound,
              (s) => _esc = _esc.copyWith(sound: s)),
          _soundPicker('Escalation sound', _esc.escalationSound,
              (s) => _esc = _esc.copyWith(escalationSound: s)),
          _slider('Switch after', _esc.sirenAfterSeconds.toDouble(), 0, 600,
              _esc.sirenAfterSeconds == 0
                  ? 'immediately'
                  : '${(_esc.sirenAfterSeconds / 60).toStringAsFixed(1)} min',
              (v) => _esc = _esc.copyWith(sirenAfterSeconds: v.round()),
              divisions: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Flash the screen'),
            subtitle: const Text('Visual alarm for when sound may not be heard'),
            value: _esc.flashScreen,
            onChanged: (on) =>
                setState(() => _esc = _esc.copyWith(flashScreen: on)),
          ),
          _slider('Snoozes allowed', _esc.maxSnoozes.toDouble(), 0, 3,
              '${_esc.maxSnoozes}',
              (v) => _esc = _esc.copyWith(maxSnoozes: v.round()),
              divisions: 3),
          section('Prove it\'s done'),
          SegmentedButton<ProofMode>(
            segments: const [
              ButtonSegment(value: ProofMode.all, label: Text('All of these')),
              ButtonSegment(value: ProofMode.any, label: Text('Any one')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Math problems'),
            value: _math != null,
            onChanged: (on) =>
                setState(() => _math = on! ? const MathProof() : null),
          ),
          if (_math != null) ...[
            _slider('Problems', _math!.problems.toDouble(), 1, 10,
                '${_math!.problems}',
                (v) => _math = MathProof(
                    problems: v.round(), difficulty: _math!.difficulty),
                divisions: 9),
            _slider('Difficulty', _math!.difficulty.toDouble(), 1, 3,
                const ['Easy', 'Medium', 'Hard'][_math!.difficulty - 1],
                (v) => _math =
                    MathProof(problems: _math!.problems, difficulty: v.round()),
                divisions: 2),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Type a random phrase'),
            value: _typing != null,
            onChanged: (on) =>
                setState(() => _typing = on! ? const TypingProof() : null),
          ),
          if (_typing != null)
            _slider('Words', _typing!.words.toDouble(), 3, 20,
                '${_typing!.words}',
                (v) => _typing = TypingProof(words: v.round()),
                divisions: 17),
          for (final label in const [
            'Scan a QR code / NFC tag',
            'Go to a place / walk steps',
            'Photo of the finished task',
          ])
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              enabled: false,
              value: false,
              onChanged: null,
              title: Text(label),
              subtitle: const Text('Coming in a later beta'),
            ),
        ],
      ),
    );
  }

  Widget _soundPicker(
      String label, AlarmSound value, void Function(AlarmSound) apply) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<AlarmSound>(
              initialValue: value,
              isExpanded: true,
              itemHeight: null,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder()),
              selectedItemBuilder: (_) => [
                for (final s in AlarmSound.values)
                  Text('${s.label} · ${s.loudness.label}',
                      overflow: TextOverflow.ellipsis),
              ],
              items: [
                for (final s in AlarmSound.values)
                  DropdownMenuItem(
                    value: s,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          s.forHardOfHearing ? Icons.hearing : Icons.volume_up),
                      title: Text(
                          '${s.label} · ${s.loudness.label} (${s.loudness.level})'),
                      subtitle: Text(s.detail),
                    ),
                  ),
              ],
              onChanged: (s) {
                if (s != null) setState(() => apply(s));
              },
            ),
          ),
          IconButton(
            tooltip: 'Preview',
            icon: const Icon(Icons.play_arrow),
            onPressed: () => SoundPreview.play(value.file),
          ),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      String display, void Function(double) apply,
      {int? divisions}) {
    return Row(
      children: [
        SizedBox(width: 140, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) => setState(() => apply(v)),
          ),
        ),
        SizedBox(width: 80, child: Text(display, textAlign: TextAlign.end)),
      ],
    );
  }
}
