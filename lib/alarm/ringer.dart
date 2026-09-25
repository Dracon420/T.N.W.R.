import 'package:flutter/foundation.dart';

import '../core/escalation.dart';
import '../core/models.dart';
import 'alarm_player.dart';
import 'system_volume.dart';

/// Plays the looping alarm sound and pushes the volume up to match the
/// escalation state. Turning the volume down or muting only lasts until the
/// next tick.
class Ringer {
  Ringer(this._volume);

  final SystemVolume _volume;
  final AlarmPlayer _player = AlarmPlayer();
  AlarmSound? _playing;
  double? _volumeBeforeAlarm;

  bool get isRinging => _playing != null;

  Future<void> apply(EscalationState state) async {
    if (_playing != state.sound) {
      if (_playing == null && _volume.isSupported) {
        _volumeBeforeAlarm = await _safe(_volume.get);
      }
      _playing = state.sound;
      await _safe(() => _player.loop(state.sound.file));
    }

    if (_volume.isSupported) {
      final current = await _safe(_volume.get);
      if (current == null || current < state.volume - 0.01) {
        await _safe(() => _volume.set(state.volume));
      }
    } else {
      // No system volume control yet on this platform: ramp the player only.
      await _safe(() => _player.setVolume(state.volume));
    }
  }

  Future<void> stop() async {
    if (_playing == null) return;
    _playing = null;
    await _safe(_player.stop);
    final restore = _volumeBeforeAlarm;
    _volumeBeforeAlarm = null;
    if (restore != null) await _safe(() => _volume.set(restore));
  }

  /// A missing audio device must never crash the alarm loop.
  Future<T?> _safe<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      debugPrint('alarm audio call failed: $e');
      return null;
    }
  }
}
