import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/models.dart';
import 'proof.dart';

bool get hasCameraScanner => Platform.isAndroid || Platform.isIOS;

/// Setup: scan the code that will have to be scanned later. Any barcode or
/// QR code works, e.g. the barcode on a medicine bottle.
Future<String?> scanCode(BuildContext context, {required String title}) =>
    Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: _Scanner(onCode: (code) => Navigator.of(context).pop(code)),
      ),
    ));

class ScanChallenge extends ProofChallenge {
  const ScanChallenge(this.spec);
  final QrProof spec;

  @override
  String get title =>
      spec.label.isEmpty ? 'Scan your code' : 'Scan the ${spec.label}';
  @override
  String get description => 'Go to where the code is and scan it.';
  @override
  bool get isSupportedHere => hasCameraScanner;
  @override
  String get unsupportedHint => 'Do this one on your phone.';
  @override
  Widget build(VoidCallback onPassed) => _ScanView(spec: spec, onPassed: onPassed);
}

class _ScanView extends StatefulWidget {
  const _ScanView({required this.spec, required this.onPassed});
  final QrProof spec;
  final VoidCallback onPassed;

  @override
  State<_ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<_ScanView> {
  String? _error;
  bool _done = false;

  void _onCode(String code) {
    if (_done) return;
    if (code == widget.spec.code) {
      _done = true;
      widget.onPassed();
    } else {
      setState(() => _error = "That's a different code. Find the right one.");
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(height: 320, child: _Scanner(onCode: _onCode)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      );
}

class _Scanner extends StatefulWidget {
  const _Scanner({required this.onCode});
  final void Function(String code) onCode;

  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code != null && code.isNotEmpty) widget.onCode(code);
        },
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Can't use the camera: ${error.errorCode.name}. "
                'Allow camera access for T.N.W.R. in the phone settings.'),
          ),
        ),
      );
}
