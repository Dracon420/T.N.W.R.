import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_config.dart';

/// The optional online backend (Supabase), used by Alexa and photo approval.
/// Each install signs in anonymously: no account for the user to make.
class Cloud {
  static Future<bool>? _ready;

  static bool get configured => cloudConfigured;
  static SupabaseClient get client => Supabase.instance.client;

  /// Connects once; true when the backend is usable.
  static Future<bool> ensureReady() => _ready ??= _connect();

  static Future<bool> _connect() async {
    if (!configured) return false;
    try {
      await Supabase.initialize(
          url: supabaseUrl, publishableKey: supabasePublishableKey);
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously();
      }
      return true;
    } catch (e) {
      debugPrint('cloud connect failed: $e');
      _ready = null; // Allow a retry later.
      return false;
    }
  }
}
