import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/models.dart';
import 'proof.dart';

bool get hasGps => Platform.isAndroid || Platform.isIOS;

/// Current position, asking for location permission if needed. Throws a
/// readable message if location is off or denied.
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw 'Location is turned off. Turn it on in the phone settings.';
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw 'T.N.W.R. needs location access for this. Allow it in the phone settings.';
  }
  return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
}

class LocationChallenge extends ProofChallenge {
  const LocationChallenge(this.spec);
  final LocationProof spec;

  String get _place =>
      spec.label.isEmpty || spec.label == 'the spot' ? 'the saved spot' : spec.label;

  @override
  String get title => 'Go to $_place';
  @override
  String get description =>
      'Be within ${spec.radiusMeters.round()} m of $_place, then check in.';
  @override
  bool get isSupportedHere => hasGps;
  @override
  String get unsupportedHint => 'Do this one on your phone.';
  @override
  Widget build(VoidCallback onPassed) =>
      _LocationView(spec: spec, onPassed: onPassed);
}

class _LocationView extends StatefulWidget {
  const _LocationView({required this.spec, required this.onPassed});
  final LocationProof spec;
  final VoidCallback onPassed;

  @override
  State<_LocationView> createState() => _LocationViewState();
}

class _LocationViewState extends State<_LocationView> {
  String? _status;
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final here = await currentPosition();
      final meters = Geolocator.distanceBetween(
          here.latitude, here.longitude, widget.spec.lat, widget.spec.lng);
      // GPS accuracy counts in the user's favour, up to the radius itself.
      final slack = here.accuracy.clamp(0, widget.spec.radiusMeters);
      if (meters <= widget.spec.radiusMeters + slack) {
        widget.onPassed();
        return;
      }
      setState(() => _status = meters >= 1000
          ? "You're ${(meters / 1000).toStringAsFixed(1)} km away."
          : "You're ${meters.round()} m away. Get closer.");
    } catch (e) {
      setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 64),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.my_location),
            label: const Text("I'm here, check in"),
            onPressed: _checking ? null : _check,
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!, textAlign: TextAlign.center),
          ],
        ],
      );
}
