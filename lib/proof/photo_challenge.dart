import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import 'proof.dart';

/// On-device image labeling (Google ML Kit): free, offline, phones only.
bool get hasPhotoCheck => Platform.isAndroid || Platform.isIOS;

/// Share of the reference labels that the new photo also shows (0..1).
double photoMatch(List<String> reference, List<String> taken) {
  if (reference.isEmpty) return 0;
  final seen = taken.map((l) => l.toLowerCase()).toSet();
  return reference.where((l) => seen.contains(l.toLowerCase())).length /
      reference.length;
}

/// Camera only (no gallery), so it has to be a fresh photo.
Future<File?> _takePhoto() async {
  final shot = await ImagePicker().pickImage(
      source: ImageSource.camera, maxWidth: 1280, imageQuality: 85);
  return shot == null ? null : File(shot.path);
}

Future<List<String>> _labels(File photo, {required double minConfidence}) async {
  final labeler =
      ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: minConfidence));
  try {
    final labels = await labeler.processImage(InputImage.fromFilePath(photo.path));
    labels.sort((a, b) => b.confidence.compareTo(a.confidence));
    return [for (final l in labels.take(10)) l.label];
  } finally {
    await labeler.close();
  }
}

/// Setup: photograph what "done" looks like. Returns null if cancelled or
/// nothing recognisable was in the photo.
Future<PhotoProof?> takeReferencePhoto(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final shot = await _takePhoto();
  if (shot == null) return null;
  // Confident labels only, so the check targets what's clearly there.
  final labels = await _labels(shot, minConfidence: 0.6);
  if (labels.isEmpty) {
    messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't recognise anything in that photo. Try again "
            'with the object filling more of the picture.')));
    return null;
  }
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/photos');
  await dir.create(recursive: true);
  final saved = await shot.copy('${dir.path}/${const Uuid().v4()}.jpg');
  return PhotoProof(referencePath: saved.path, referenceLabels: labels);
}

class PhotoChallenge extends ProofChallenge {
  const PhotoChallenge(this.spec);
  final PhotoProof spec;

  @override
  String get title => 'Photo of the finished task';
  @override
  String get description =>
      'Take a photo like the one you took when setting this up.';
  @override
  bool get isSupportedHere => hasPhotoCheck;
  @override
  String get unsupportedHint => 'Do this one on your phone.';
  @override
  Widget build(VoidCallback onPassed) => _PhotoView(spec: spec, onPassed: onPassed);
}

class _PhotoView extends StatefulWidget {
  const _PhotoView({required this.spec, required this.onPassed});
  final PhotoProof spec;
  final VoidCallback onPassed;

  @override
  State<_PhotoView> createState() => _PhotoViewState();
}

class _PhotoViewState extends State<_PhotoView> {
  String? _status;
  bool _busy = false;

  Future<void> _shoot() async {
    setState(() => _busy = true);
    try {
      final shot = await _takePhoto();
      if (shot == null) return;
      final seen = await _labels(shot, minConfidence: 0.5);
      final score = photoMatch(widget.spec.referenceLabels, seen);
      if (score >= widget.spec.threshold) {
        widget.onPassed();
        return;
      }
      setState(() => _status = "That doesn't look like the reference photo "
          '(${(score * 100).round()}% match). Looking for: '
          '${widget.spec.referenceLabels.take(4).join(', ')}.');
    } catch (e) {
      setState(() => _status = "Couldn't check the photo: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reference = File(widget.spec.referencePath);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reference.existsSync()) ...[
          const Text('It should look like this:'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(reference, height: 200, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          icon: const Icon(Icons.photo_camera),
          label: const Text('Take photo'),
          onPressed: _busy ? null : _shoot,
        ),
        if (_busy) const Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
        if (_status != null) ...[
          const SizedBox(height: 12),
          Text(_status!, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
