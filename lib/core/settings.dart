import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// App-wide preferences, kept in settings.json next to tasks.json.
class AppSettings extends ChangeNotifier {
  AppSettings(this._file);

  final File _file;
  ThemeMode _themeMode = ThemeMode.system;
  bool _pauseDuringCalls = true;
  int _callResumeDelaySeconds = 30;

  ThemeMode get themeMode => _themeMode;

  /// Silence a ringing alarm while the user is on a call or video chat.
  bool get pauseDuringCalls => _pauseDuringCalls;

  /// How long after a call ends before the alarm comes back.
  int get callResumeDelaySeconds => _callResumeDelaySeconds;

  Future<void> load() async {
    try {
      final j = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      _themeMode =
          ThemeMode.values.asNameMap()[j['themeMode']] ?? ThemeMode.system;
      _pauseDuringCalls = j['pauseDuringCalls'] as bool? ?? true;
      _callResumeDelaySeconds = j['callResumeDelaySeconds'] as int? ?? 30;
    } on FileSystemException {
      // First run: keep defaults.
    } on FormatException {
      // Unreadable settings aren't worth failing startup over.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) => _update(() => _themeMode = mode);

  Future<void> setPauseDuringCalls(bool on) =>
      _update(() => _pauseDuringCalls = on);

  Future<void> setCallResumeDelaySeconds(int seconds) =>
      _update(() => _callResumeDelaySeconds = seconds);

  Future<void> _update(void Function() change) async {
    change();
    notifyListeners();
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode({
      'themeMode': _themeMode.name,
      'pauseDuringCalls': _pauseDuringCalls,
      'callResumeDelaySeconds': _callResumeDelaySeconds,
    }));
  }
}
