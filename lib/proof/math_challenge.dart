import 'dart:math';

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'proof.dart';

class MathProblem {
  final String question;
  final int answer;
  const MathProblem(this.question, this.answer);
}

MathProblem generateProblem(int difficulty, Random rng) {
  int between(int lo, int hi) => lo + rng.nextInt(hi - lo + 1);
  switch (difficulty) {
    case <= 1:
      final a = between(10, 99), b = between(10, 99);
      return MathProblem('$a + $b', a + b);
    case 2:
      final a = between(3, 12), b = between(3, 12), c = between(10, 99);
      return MathProblem('$a × $b + $c', a * b + c);
    default:
      final a = between(12, 29), b = between(6, 15);
      final c = between(10, min(99, a * b));
      return MathProblem('$a × $b − $c', a * b - c);
  }
}

class MathChallenge extends ProofChallenge {
  const MathChallenge(this.spec);
  final MathProof spec;

  @override
  String get title => 'Solve ${spec.problems} math problem'
      '${spec.problems == 1 ? '' : 's'}';
  @override
  String get description => 'A wrong answer starts the count over.';
  @override
  Widget build(VoidCallback onPassed) =>
      _MathView(spec: spec, onPassed: onPassed);
}

class _MathView extends StatefulWidget {
  const _MathView({required this.spec, required this.onPassed});
  final MathProof spec;
  final VoidCallback onPassed;

  @override
  State<_MathView> createState() => _MathViewState();
}

class _MathViewState extends State<_MathView> {
  final _rng = Random();
  final _input = TextEditingController();
  late MathProblem _problem = generateProblem(widget.spec.difficulty, _rng);
  int _solved = 0;
  String? _error;

  void _submit() {
    final guess = int.tryParse(_input.text.trim());
    setState(() {
      if (guess == _problem.answer) {
        _solved++;
        _error = null;
      } else {
        _solved = 0;
        _error = 'Wrong! Back to zero.';
      }
      _problem = generateProblem(widget.spec.difficulty, _rng);
      _input.clear();
    });
    if (_solved >= widget.spec.problems) widget.onPassed();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$_solved / ${widget.spec.problems} solved',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Text('${_problem.question} = ?',
            style: theme.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _input,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
                border: const OutlineInputBorder(), errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _submit, child: const Text('Check')),
      ],
    );
  }
}
