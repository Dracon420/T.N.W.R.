import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import '../core/models.dart';
import 'proof.dart';

// iPhone NFC needs a paid Apple developer account (the NFC capability), so
// it's Android-only for the beta.
bool get hasNfcReader => Platform.isAndroid;

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');

/// Reads one tag's ID; null if NFC is off/unsupported or it was cancelled.
Future<String?> _readTagId() async {
  if (await NfcManager.instance.checkAvailability() != NfcAvailability.enabled) {
    return null;
  }
  final done = Completer<String?>();
  await NfcManager.instance.startSession(
    pollingOptions: const {
      NfcPollingOption.iso14443,
      NfcPollingOption.iso15693,
      NfcPollingOption.iso18092,
    },
    onDiscovered: (tag) {
      final id = NfcTagAndroid.from(tag)?.id;
      if (id != null && !done.isCompleted) done.complete(_hex(id));
    },
  );
  try {
    return await done.future;
  } finally {
    await NfcManager.instance.stopSession();
  }
}

/// Setup: tap the tag that will have to be tapped later.
Future<String?> readNfcTag(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await NfcManager.instance.checkAvailability() != NfcAvailability.enabled) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Turn on NFC in the phone settings first.')));
    return null;
  }
  if (!context.mounted) return null;
  final read = _readTagId();
  final id = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      read.then((id) {
        if (dialogContext.mounted) Navigator.of(dialogContext).pop(id);
      });
      return AlertDialog(
        icon: const Icon(Icons.nfc, size: 48),
        title: const Text('Hold the tag to the back of the phone'),
        actions: [
          TextButton(
            onPressed: () {
              NfcManager.instance.stopSession();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
  return id;
}

class NfcChallenge extends ProofChallenge {
  const NfcChallenge(this.spec);
  final NfcProof spec;

  @override
  String get title =>
      spec.label.isEmpty ? 'Tap your NFC tag' : 'Tap the ${spec.label} tag';
  @override
  String get description => 'Go to the tag and hold the phone to it.';
  @override
  bool get isSupportedHere => hasNfcReader;
  @override
  String get unsupportedHint => 'Do this one on your Android phone.';
  @override
  Widget build(VoidCallback onPassed) => _NfcView(spec: spec, onPassed: onPassed);
}

class _NfcView extends StatefulWidget {
  const _NfcView({required this.spec, required this.onPassed});
  final NfcProof spec;
  final VoidCallback onPassed;

  @override
  State<_NfcView> createState() => _NfcViewState();
}

class _NfcViewState extends State<_NfcView> {
  String _status = 'Waiting for the tag…';
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    while (_active) {
      final id = await _readTagId();
      if (!_active) return;
      if (id == null) {
        setState(() => _status = 'NFC is off. Turn it on in the phone settings.');
        return;
      }
      if (id == widget.spec.tagId) {
        _active = false;
        widget.onPassed();
        return;
      }
      setState(() => _status = "That's a different tag. Find the right one.");
    }
  }

  @override
  void dispose() {
    _active = false;
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.nfc, size: 72),
          const SizedBox(height: 12),
          Text(_status, textAlign: TextAlign.center),
        ],
      );
}
