import 'dart:io';

import 'package:flutter/services.dart';

/// Tells whether the user is on a phone call or voice/video chat, so the
/// alarm can wait until it's over. Android: MainActivity.kt. iPhone
/// (CXCallObserver) comes with the iOS alarm engine.
class CallDetector {
  static const _channel = MethodChannel('nag_alarm/calls');

  bool get isSupported => Platform.isAndroid;

  Future<bool> isInCall() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isInCall') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
