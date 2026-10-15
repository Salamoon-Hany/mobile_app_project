import 'secure_api.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/selected_location.dart';

class LocationProblem implements Exception {
  final String message;
  final bool openAppSettings;
  final bool openLocationSettings;
  const LocationProblem(
    this.message, {
    this.openAppSettings = false,
    this.openLocationSettings = false,
  });
}

class LocationService {
  final http.Client? client;
  LocationService({this.client});
  Future<http.Response> _get(Uri uri) => client != null
      ? client!.get(secureEndpoint(uri))
      : http.get(secureEndpoint(uri));
  static const _base = String.fromEnvironment(
    'GEOCODER_URL',
    defaultValue: 'https://photon.komoot.io',
  );

  Future<SelectedLocation> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationProblem(
        'Turn on location services, then tap Locate me again.',
        openLocationSettings: true,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationProblem(
        'Location permission is blocked. Enable it in app settings or search for an area.',
        openAppSettings: true,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationProblem(
        'Location permission was denied. Allow it or search for an area.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
    // Keep the real GPS fix even when the reverse geocoder is unavailable.
    var label = 'Current location';
    try {
      final response = await _get(
        Uri.parse('$_base/reverse').replace(
          queryParameters: {
            'lat': '${position.latitude}',
            'lon': '${position.longitude}',
            'limit': '1',
          },
        ),
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final features = (jsonDecode(response.body) as Map)['features'] as List;
        if (features.isNotEmpty) {
          label = SelectedLocation.fromPhoton(
            Map<String, dynamic>.from(features.first as Map),
          ).label;
        }
      }
    } catch (_) {
      /* GPS coordinates remain usable without a place label. */
    }
    return SelectedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      label: label,
      fromGps: true,
    );
  }

  Future<List<SelectedLocation>> search(String query) async {
    if (query.trim().length < 3) {
      throw const LocationProblem('Enter at least three characters.');
    }
    final response = await _get(
      Uri.parse('$_base/api/').replace(
        queryParameters: {
          'q': query.trim(), 'limit': '6',
          // Prefer nearby Egyptian results without hiding results in other countries.
          'lat': '30.0444', 'lon': '31.2357',
        },
      ),
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw const LocationProblem(
        'Area search is unavailable. Try Locate me or retry later.',
      );
    }
    final features = (jsonDecode(response.body) as Map)['features'] as List;
    return features
        .map(
          (f) =>
              SelectedLocation.fromPhoton(Map<String, dynamic>.from(f as Map)),
        )
        .toList();
  }
}
