import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cloud.dart';
import '../core/models.dart';
import '../core/task_store.dart';

/// Links this install to an Echo and keeps the Echo's reminders in step with
/// the app's upcoming tasks (supabase/functions/alexa-* and alexa/lambda).
///
/// The Echo reminds at the due time, then every [repeatEveryMinutes] minutes,
/// [repeatCount] times in total, until the task is proven done in the app.
class AlexaLink extends ChangeNotifier {
  AlexaLink(this.store);

  static const repeatEveryMinutes = 5;
  static const repeatCount = 10;

  /// Only tasks this soon are sent, to stay within Alexa's message size.
  static const horizon = Duration(days: 7);
  static const maxTasks = 25;

  final TaskStore store;
  bool linked = false;
  String? lastError;
  Timer? _debounce;
  bool _ready = false;

  bool get available => Cloud.configured;
  SupabaseClient get _db => Cloud.client;

  Future<void> init() async {
    if (!available) return;
    try {
      if (!await Cloud.ensureReady()) throw 'no connection';
      _ready = true;
      store.addListener(_scheduleSync);
      await refresh();
    } catch (e) {
      lastError = 'Could not reach the server: $e';
      notifyListeners();
    }
  }

  /// Re-reads whether this install is linked (e.g. after saying the code).
  Future<void> refresh() async {
    if (!_ready) return;
    final row = await _db.from('alexa_links').select('linked_at').maybeSingle();
    final wasLinked = linked;
    linked = row != null;
    notifyListeners();
    if (linked && !wasLinked) await sync();
  }

  /// A 6-digit code to say to the skill; valid 10 minutes.
  Future<String> newCode() async {
    final res = await _db.functions.invoke('alexa-code');
    return (res.data as Map)['code'] as String;
  }

  Future<void> unlink() async {
    // Clear the Echo's reminders first, while the link still exists.
    await _send(const []);
    await _db.from('alexa_links').delete().eq('app_user', _db.auth.currentUser!.id);
    linked = false;
    notifyListeners();
  }

  void _scheduleSync() {
    if (!linked) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), sync);
  }

  Future<void> sync() => _send(payload(store.tasks, DateTime.now()));

  Future<void> _send(List<Map<String, dynamic>> tasks) async {
    if (!_ready || !linked) return;
    try {
      await _db.functions.invoke('alexa-sync', body: {'tasks': tasks});
      lastError = null;
    } catch (e) {
      lastError = 'Alexa sync failed: $e';
    }
    notifyListeners();
  }

  /// Everything not yet proven done, soonest first. Ringing tasks stay in the
  /// list (same due time), so the Echo keeps nagging until the proof passes.
  @visibleForTesting
  static List<Map<String, dynamic>> payload(List<NagTask> tasks, DateTime now) {
    final local = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final upcoming = tasks
        .where((t) => t.status != TaskStatus.done && t.dueAt.isBefore(now.add(horizon)))
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return [
      for (final t in upcoming.take(maxTasks))
        {
          'id': t.id,
          'title': t.title.length > 60 ? t.title.substring(0, 60) : t.title,
          // Wall-clock time; the Echo applies its own time zone.
          'at': local.format(t.dueAt),
          'everyMin': repeatEveryMinutes,
          'count': repeatCount,
        }
    ];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    store.removeListener(_scheduleSync);
    super.dispose();
  }
}
