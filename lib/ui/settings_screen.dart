import 'package:flutter/material.dart';

import '../core/settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Text(text, style: theme.textTheme.titleMedium),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            section('Appearance'),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('System')),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Light')),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
            section('Phone calls'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pause alarms during calls'),
              subtitle: const Text(
                  'Phone calls, video chats and FaceTime-style calls. The alarm '
                  'goes quiet during the call and comes back afterwards at the '
                  'same loudness. The task still has to be proven.'),
              value: settings.pauseDuringCalls,
              onChanged: settings.setPauseDuringCalls,
            ),
            if (settings.pauseDuringCalls)
              Row(
                children: [
                  const SizedBox(width: 140, child: Text('Resume after call')),
                  Expanded(
                    child: Slider(
                      value: settings.callResumeDelaySeconds.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 8,
                      onChanged: (v) =>
                          settings.setCallResumeDelaySeconds(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                        settings.callResumeDelaySeconds == 0
                            ? 'right away'
                            : '${settings.callResumeDelaySeconds} s',
                        textAlign: TextAlign.end),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
