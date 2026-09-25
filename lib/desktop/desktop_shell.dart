import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app_controller.dart';
import '../core/branding.dart';

/// Windows/macOS behavior: lives in the tray, starts at login, and while an
/// alarm rings, takes over the screen and refuses to close.
class DesktopShell with WindowListener implements AlarmSurface {
  bool _ringing = false;
  Timer? _refocus;
  TrayIcon? _tray;
  MenuItem? _quitItem;

  static bool get isDesktop => Platform.isWindows || Platform.isMacOS;

  Future<void> init({required bool startHidden}) async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    const options = WindowOptions(
      size: Size(480, 760),
      minimumSize: Size(380, 560),
      center: true,
      title: appName,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (!startHidden) await _bringToFront();
    });

    _initTray();

    // Only register the release build, so debug runs don't end up at login.
    if (kReleaseMode) {
      launchAtStartup.setup(
        appName: appName,
        appPath: Platform.resolvedExecutable,
        args: ['--minimized'],
      );
      await launchAtStartup.enable();
    }
  }

  void _initTray() {
    final tray = TrayIcon.create();
    if (tray == null) return; // No tray available; the window still works.
    tray.icon = ImageAsset.fromAsset('assets/icons/tray.png');
    tray.setTooltip('$appName - $appTagline');

    final menu = Menu.create()!;
    final open =
        MenuItem.createWithLabelAndType('Open $appName', MenuItemType.normal)!;
    open.addListener((e) {
      if (e is MenuItemClickedEvent) _bringToFront();
    });
    final quit = MenuItem.createWithLabelAndType('Quit', MenuItemType.normal)!;
    quit.addListener((e) {
      if (e is MenuItemClickedEvent && !_ringing) _quit();
    });
    menu
      ..addItem(open)
      ..addSeparator()
      ..addItem(quit);

    tray
      ..setContextMenu(menu)
      ..setContextMenuTrigger(ContextMenuTrigger.rightClicked)
      ..addListener((e) {
        if (e is TrayIconClickedEvent) _bringToFront();
      })
      ..setVisible(true);
    _tray = tray;
    _quitItem = quit;
  }

  void _updateQuitItem() {
    _quitItem
      ?..label = _ringing ? "Can't quit while an alarm is ringing" : 'Quit'
      ..isEnabled = !_ringing;
  }

  Future<void> _quit() async {
    _tray?.setVisible(false);
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  Future<void> _bringToFront() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> onRinging() async {
    _ringing = true;
    _updateQuitItem();
    await windowManager.setAlwaysOnTop(true);
    await _bringToFront();
    await windowManager.setFullScreen(true);
    // Alt-tabbing away doesn't help: the alarm window keeps pulling focus back.
    _refocus = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!await windowManager.isFocused()) await _bringToFront();
    });
  }

  @override
  Future<void> onQuiet() async {
    _ringing = false;
    _refocus?.cancel();
    _refocus = null;
    _updateQuitItem();
    await windowManager.setFullScreen(false);
    await windowManager.setAlwaysOnTop(false);
  }

  @override
  void onWindowClose() {
    // Closing the window while ringing does nothing; otherwise hide to tray.
    if (!_ringing) windowManager.hide();
  }
}
