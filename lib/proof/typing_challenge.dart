import 'dart:math';

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'proof.dart';

const _words = [
  'purple', 'monkey', 'dishwasher', 'volcano', 'pickle', 'trombone',
  'galaxy', 'sandwich', 'penguin', 'tornado', 'marshmallow', 'cactus',
  'umbrella', 'waffle', 'jellyfish', 'lighthouse', 'noodle', 'blizzard',
  'pancake', 'walrus', 'kazoo', 'avocado', 'thunder', 'hamster', 'rocket',
  'spaghetti', 'lantern', 'pretzel', 'octopus', 'meteor', 'bagel', 'giraffe',
  'harmonica', 'popcorn', 'squirrel', 'glacier', 'muffin', 'yodel',
  'zucchini', 'flamingo', 'compass', 'burrito', 'narwhal', 'tambourine',
  'cupcake', 'hurricane', 'raccoon', 'saxophone', 'dumpling', 'wombat',
];

String randomPhrase(int words, Random rng) =>
    List.generate(words, (_) => _words[rng.nextInt(_words.length)]).join(' ');

/// Case and extra spaces don't matter; every word must match.
bool phraseMatches(String target, String typed) {
  String norm(String s) => s.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
  return norm(target) == norm(typed);
}

class TypingChallenge extends ProofChallenge {
  const TypingChallenge(this.spec);
  final TypingProof spec;

  @override
  String get title => 'Type a ${spec.words}-word phrase';
  @override
  String get description => 'Copy and paste are blocked.';
  @override
  Widget build(VoidCallback onPassed) =>
      _TypingView(spec: spec, onPassed: onPassed);
}

class _TypingView extends StatefulWidget {
  const _TypingView({required this.spec, required this.onPassed});
  final TypingProof spec;
  final VoidCallback onPassed;

  @override
  State<_TypingView> createState() => _TypingViewState();
}

class _TypingViewState extends State<_TypingView> {
  final _rng = Random();
  final _input = TextEditingController();
  late String _phrase = randomPhrase(widget.spec.words, _rng);
  String? _error;

  void _submit() {
    if (phraseMatches(_phrase, _input.text)) {
      widget.onPassed();
      return;
    }
    setState(() {
      _error = 'Not quite. Here is a new phrase.';
      _phrase = randomPhrase(widget.spec.words, _rng);
      _input.clear();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Plain Text (not selectable) so the phrase can't be copied.
          Text(_phrase,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            autofocus: true,
            enableInteractiveSelection: false,
            contextMenuBuilder: null,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Type the phrase above',
                errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _submit, child: const Text('Check')),
        ],
      ),
    );
  }
}
