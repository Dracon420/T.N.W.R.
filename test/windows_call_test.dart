import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/alarm/call_detector.dart';

void main() {
  test('reads the real Windows mic/camera usage records without failing', () {
    // Nothing should be using the mic on a build machine; mostly this proves
    // the registry paths and value types are read correctly.
    expect(windowsMicOrCameraInUse(), isA<bool>());
  }, skip: !Platform.isWindows);
}
