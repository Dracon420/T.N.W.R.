import 'dart:async';

import 'package:flutter/material.dart';

import '../alexa/alexa_link.dart';
import 'insets.dart';

/// Connect an Echo: get a code here, say it to the "naggy wife" skill.
class AlexaScreen extends StatefulWidget {
  const AlexaScreen({super.key, required this.alexa});

  final AlexaLink alexa;

  @override
  State<AlexaScreen> createState() => _AlexaScreenState();
}

class _AlexaScreenState extends State<AlexaScreen> {
  String? _code;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _getCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await widget.alexa.newCode();
      setState(() => _code = code);
      // Watch for the skill redeeming it.
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
        await widget.alexa.refresh();
        if (widget.alexa.linked) t.cancel();
      });
    } catch (e) {
      setState(() => _error = "Couldn't get a code: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Alexa')),
      body: ListenableBuilder(
        listenable: widget.alexa,
        builder: (context, _) {
          final alexa = widget.alexa;
          if (!alexa.available) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text("Alexa isn't set up for this build yet."),
            );
          }
          return ListView(
            padding: screenListPadding(context),
            children: [
              if (alexa.linked) ...[
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle, color: Colors.green, size: 36),
                  title: Text('Connected to Alexa'),
                  subtitle: Text(
                      'When a reminder is due, your Echo says it, then repeats it every '
                      '${AlexaLink.repeatEveryMinutes} minutes (up to '
                      '${AlexaLink.repeatCount} times) until you prove it done here.'),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 12, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                    onPressed: alexa.sync,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                    onPressed: alexa.unlink,
                  ),
                ]),
                const SizedBox(height: 24),
                Text('Try it: "Alexa, ask naggy wife what\'s due."',
                    style: theme.textTheme.bodyLarge),
              ] else ...[
                Text('Connect your Echo', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                const _Step(1, 'In the Alexa app, enable the "Naggy Wife" skill. '
                    '(Beta testers: accept the email invite first.)'),
                const _Step(2, 'Tap "Get code" below.'),
                const _Step(3, 'Say: "Alexa, ask naggy wife to link code" and '
                    'then the six digits.'),
                const _Step(4, 'When Alexa asks for permission to set reminders, say yes.'),
                const SizedBox(height: 16),
                if (_code != null) ...[
                  Center(
                    child: Text(
                      '${_code!.substring(0, 3)} ${_code!.substring(3)}',
                      style: theme.textTheme.displayMedium
                          ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4),
                    ),
                  ),
                  const Center(child: Text('Valid for 10 minutes. Waiting for Alexa…')),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  icon: const Icon(Icons.pin),
                  label: Text(_code == null ? 'Get code' : 'Get a new code'),
                  onPressed: _busy ? null : _getCode,
                ),
              ],
              if (_error ?? alexa.lastError case final error?) ...[
                const SizedBox(height: 16),
                Text(error, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(radius: 14, child: Text('$number')),
        title: Text(text),
      );
}
