class SelectedLocation {
  final double latitude;
  final double longitude;
  final String label;
  final bool fromGps;
  const SelectedLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.fromGps = false,
  });

  factory SelectedLocation.fromPhoton(Map<String, dynamic> feature) {
    final coordinates = ((feature['geometry'] as Map)['coordinates'] as List);
    final props = feature['properties'] as Map;
    final parts = <String>{
      for (final key in [
        'name',
        'street',
        'district',
        'city',
        'state',
        'country',
      ])
        if (props[key] is String && (props[key] as String).isNotEmpty)
          props[key] as String,
    };
    return SelectedLocation(
      latitude: (coordinates[1] as num).toDouble(),
      longitude: (coordinates[0] as num).toDouble(),
      label: parts.isEmpty ? 'Selected area' : parts.join(', '),
    );
  }
  String get coordinates =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}
