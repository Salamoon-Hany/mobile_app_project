import '../l10n/app_language.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/selected_location.dart';
import '../services/location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final LocationService? service;
  const LocationPickerScreen({super.key, this.service});
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _query = TextEditingController();
  late final _service = widget.service ?? LocationService();
  List<SelectedLocation> _results = [];
  SelectedLocation? _selection;
  bool _busy = false;
  bool _searched = false;
  String? _error;
  LocationProblem? _problem;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(bool gps) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _problem = null;
      _selection = null;
      _results = [];
      _searched = false;
    });
    try {
      if (gps) {
        final selection = await _service.locate();
        if (!mounted) return;
        setState(() {
          _selection = selection;
          _results = [];
          _searched = false;
        });
      } else {
        final results = await _service.search(_query.text);
        if (!mounted) return;
        setState(() {
          _results = results;
          _searched = true;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _problem = error is LocationProblem ? error : null;
        _error = error is LocationProblem
            ? error.message
            : error is TimeoutException
            ? 'Location request timed out. Retry or use the other option.'
            : 'Could not find your location. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Choose service area')),
    bottomNavigationBar: _selection == null
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.pop(context, _selection),
                child: const AppText('Use this location'),
              ),
            ),
          ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AppText(
            'Find your location',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(true),
            icon: const Icon(Icons.my_location),
            label: const AppText('Locate me'),
          ),
          const SizedBox(height: 20),
          const AppText('Or search for the area'),
          const SizedBox(height: 8),
          TextField(
            controller: _query,
            enabled: !_busy,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(false),
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: tr('Search for the area'),
              hintText: tr('e.g. Dokki, Giza / الدقي'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(false),
            icon: const Icon(Icons.search),
            label: const AppText('Search'),
          ),
          const AppText(
            'Search runs when you press Search. Place data: © OpenStreetMap contributors, via Photon.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            AppText(_error!, style: const TextStyle(color: Colors.red)),
          if (!kIsWeb && (_problem?.openAppSettings ?? false))
            TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: const AppText('Open app settings'),
            ),
          if (!kIsWeb && (_problem?.openLocationSettings ?? false))
            TextButton(
              onPressed: () => Geolocator.openLocationSettings(),
              child: const AppText('Open location settings'),
            ),
          if (_searched && _results.isEmpty && !_busy && _error == null)
            const AppText(
              'No areas found. Add the city/country or try another spelling.',
            ),
          for (final location in _results)
            Card(
              child: ListTile(
                title: AppText(location.label),
                subtitle: AppText(location.coordinates),
                leading: const Icon(Icons.place_outlined),
                selected: identical(location, _selection),
                trailing: identical(location, _selection)
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: _busy
                    ? null
                    : () => setState(() => _selection = location),
              ),
            ),
          if (_selection != null) ...[
            const SizedBox(height: 16),
            AppText(
              'Selected: ${_selection!.label}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            AppText(_selection!.coordinates),
            const AppText(
              'Area search selects an approximate area. Add your street, building and apartment in the booking details.',
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );
}
