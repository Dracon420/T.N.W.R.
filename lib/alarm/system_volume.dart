import 'dart:io';

import 'package:flutter/services.dart';

/// Reads and raises the device's master volume. Implemented natively in
/// windows/runner/flutter_window.cpp; other platforms get their own later.
class SystemVolume {
  static const _channel = MethodChannel('nag_alarm/volume');

  bool get isSupported => Platform.isWindows;

  /// 0..1, where muted reads as 0.
  Future<double> get() async =>
      await _channel.invokeMethod<double>('get') ?? 0;

  /// Sets the volume and unmutes.
  Future<void> set(double level) => _channel.invokeMethod('set', level);
}
