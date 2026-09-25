import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Keeps tasks in a JSON file on the device. Supabase sync will sit on top of
/// this later; alarms always run from the local copy so they work offline.
class TaskStore extends ChangeNotifier {
  TaskStore(this._file);

  final File _file;
  final Map<String, NagTask> _tasks = {};

  List<NagTask> get tasks =>
      _tasks.values.toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  NagTask? byId(String id) => _tasks[id];

  Future<void> load() async {
    if (!await _file.exists()) return;
    try {
      final list = jsonDecode(await _file.readAsString()) as List;
      for (final j in list) {
        final t = NagTask.fromJson(j as Map<String, dynamic>);
        _tasks[t.id] = t;
      }
    } on FormatException catch (e) {
      // Keep the broken file for inspection rather than silently losing tasks.
      await _file.copy('${_file.path}.corrupt');
      debugPrint('tasks.json unreadable, starting empty: $e');
    }
    notifyListeners();
  }

  Future<void> upsert(NagTask task) async {
    _tasks[task.id] = task;
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    if (_tasks.remove(id) == null) return;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    // Write-then-rename so a crash mid-write can't corrupt the task list.
    await _file.parent.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(
        jsonEncode([for (final t in _tasks.values) t.toJson()]));
    await tmp.rename(_file.path);
  }
}
