import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// App-wide preferences, kept in settings.json next to tasks.json.
class AppSettings extends ChangeNotifier {
  AppSettings(this._file);

  final File _file;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    try {
      final j = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      _themeMode =
          ThemeMode.values.asNameMap()[j['themeMode']] ?? ThemeMode.system;
    } on FileSystemException {
      // First run: keep defaults.
    } on FormatException {
      // Unreadable settings aren't worth failing startup over.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode({'themeMode': mode.name}));
  }
}
