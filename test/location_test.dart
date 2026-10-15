import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app_project/models/selected_location.dart';
import 'package:mobile_app_project/services/location_service.dart';
import 'package:mobile_app_project/screens/location_picker.dart';

Map<String, dynamic> feature(String name, double lon, double lat) => {
  'geometry': {
    'coordinates': [lon, lat],
  },
  'properties': {'name': name, 'city': 'Giza', 'country': 'Egypt'},
};
void main() {
  test(
    'search encodes Arabic input and reads longitude/latitude in GeoJSON order',
    () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['q'], 'الدقي');
        return http.Response(
          jsonEncode({
            'features': [feature('Dokki', 31.21, 30.04)],
          }),
          200,
        );
      });
      addTearDown(client.close);
      final results = await LocationService(client: client).search('الدقي');
      expect(results.single.latitude, 30.04);
      expect(results.single.longitude, 31.21);
      expect(results.single.label, 'Dokki, Giza, Egypt');
      expect(results.single.fromGps, false);
    },
  );
  test(
    'short searches and provider failures do not fabricate a location',
    () async {
      final client = MockClient((_) async => http.Response('unavailable', 503));
      addTearDown(client.close);
      final service = LocationService(client: client);
      await expectLater(service.search('ab'), throwsA(isA<LocationProblem>()));
      await expectLater(
        service.search('Dokki'),
        throwsA(isA<LocationProblem>()),
      );
    },
  );
  testWidgets('search requires choosing a result and confirming it', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'features': [
            feature('Dokki', 31.21, 30.04),
            feature('Agouza', 31.20, 30.06),
          ],
        }),
        200,
      ),
    );
    addTearDown(client.close);
    SelectedLocation? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<SelectedLocation>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationPickerScreen(
                      service: LocationService(client: client),
                    ),
                  ),
                );
              },
              child: const Text('Pick location'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick location'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Giza');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Use this location'), findsNothing);
    expect(result, isNull);
    await tester.tap(find.text('Agouza, Giza, Egypt'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use this location'));
    await tester.tap(find.text('Use this location'));
    await tester.pumpAndSettle();
    expect(result?.label, 'Agouza, Giza, Egypt');
    expect(result?.latitude, 30.06);
  });
  testWidgets('failed new search clears old selectable area results', (
    tester,
  ) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return calls == 1
          ? http.Response(
              jsonEncode({
                'features': [feature('Dokki', 31.21, 30.04)],
              }),
              200,
            )
          : http.Response('unavailable', 503);
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: LocationPickerScreen(service: LocationService(client: client)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Dokki');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Dokki, Giza, Egypt'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Agouza');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Dokki, Giza, Egypt'), findsNothing);
    expect(find.text('Use this location'), findsNothing);
    expect(find.textContaining('Area search is unavailable'), findsOneWidget);
  });
}
