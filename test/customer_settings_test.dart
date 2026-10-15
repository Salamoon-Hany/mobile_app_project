import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/l10n/app_language.dart';
import 'package:mobile_app_project/models/customer_settings.dart';
import 'package:mobile_app_project/screens/dashboard.dart';
import 'package:mobile_app_project/screens/become_worker.dart';
import 'package:mobile_app_project/screens/app_rating.dart';
import 'package:mobile_app_project/screens/worker_home.dart';
import 'package:mobile_app_project/services/marketplace_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLanguage.code.value = 'en';
    AppState.clearAccount();
  });
  tearDown(() {
    AppState.clearAccount();
    AppLanguage.code.value = 'en';
  });
  test(
    'experience accepts zero and Arabic digits and rejects invalid or excessive values',
    () {
      expect(parseExperienceYears('0'), 0);
      expect(parseExperienceYears(' ٥ '), 5);
      expect(parseExperienceYears('۶۰'), 60);
      for (final value in ['', '-1', '61', '3.5', 'text'])
        expect(parseExperienceYears(value), null);
    },
  );
  testWidgets(
    'new Settings entries belong to customers and preserve the existing order',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MyHomePage()));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-become-worker')), findsOneWidget);
      expect(find.byKey(const Key('settings-rate-app')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Become a worker')).dy,
        greaterThan(tester.getTopLeft(find.text('Dark mode')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Rate the app')).dy,
        lessThan(tester.getTopLeft(find.byType(Divider)).dy),
      );
      Marketplace.shared.account = {
        'role': 'worker',
        'balance': 0,
        'skills': [],
      };
      await tester.pumpWidget(const MaterialApp(home: WorkerHome()));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Become a worker'), findsNothing);
      expect(find.text('Rate the app'), findsNothing);
    },
  );
  testWidgets(
    'intro opens a form with real service and country multi-selection',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BecomeWorkerScreen()));
      await tester.ensureVisible(find.text('Register Now'));
      await tester.tap(find.text('Register Now'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkerApplicationScreen), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('application-work-types')),
      );
      await tester.tap(find.byKey(const Key('application-work-types')));
      await tester.pumpAndSettle();
      expect(find.text('Cleaning'), findsNothing);
      expect(find.text('Air Conditioning'), findsNothing);
      expect(find.text('Painting'), findsNothing);
      await tester.tap(find.text('Builder'));
      await tester.tap(find.text('Plumber'));
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(find.text('Builder, Plumber'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('application-countries')),
      );
      await tester.tap(find.byKey(const Key('application-countries')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Egypt'));
      await tester.tap(find.text('UAE'));
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(find.text('Egypt, UAE'), findsOneWidget);
    },
  );
  testWidgets(
    'invalid application stays on screen and never shows submitted success',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerApplicationScreen(
            onSubmit: (_) async {
              calls++;
            },
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('application-submit')));
      await tester.tap(find.byKey(const Key('application-submit')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Choose at least one work type.'), findsOneWidget);
      expect(find.text('Choose at least one country.'), findsOneWidget);
      expect(find.text('Registration Submitted'), findsNothing);
    },
  );
  testWidgets(
    'valid submission normalizes contact and submits once, without changing customer role',
    (tester) async {
      final application = {
        'fullName': 'Ahmed Salah',
        'phone': '01012345678',
        'email': 'customer@example.com',
        'workTypes': ['builder'],
        'experienceYears': 3,
        'countries': ['EG'],
        'status': 'pending',
      };
      var calls = 0;
      Map<String, dynamic>? received;
      Marketplace.shared.account = {'role': 'customer'};
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerApplicationScreen(
            initialApplication: application,
            onSubmit: (value) async {
              calls++;
              received = value;
            },
          ),
        ),
      );
      final email = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('application-email')),
          matching: find.byType(TextField),
        ),
      );
      expect(email.readOnly, true);
      await tester.enterText(
        find.byKey(const Key('application-experience')),
        '٥',
      );
      await tester.ensureVisible(find.byKey(const Key('application-submit')));
      await tester.tap(find.byKey(const Key('application-submit')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(received!['phone'], '+201012345678');
      expect(received!['experienceYears'], 5);
      expect(received!.containsKey('email'), false);
      expect(find.text('Application updated'), findsOneWidget);
      expect(Marketplace.shared.isWorker, false);
    },
  );
  testWidgets(
    'rating starts unselected and a failed save retains the chosen stars',
    (tester) async {
      var submitted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppRatingSheet(
              onSubmit: (stars) async {
                submitted = stars;
                throw const FormatException(
                  'Could not save your rating. Please retry.',
                );
              },
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('app-rating-submit')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('app-rating-4')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('app-rating-submit')));
      await tester.pumpAndSettle();
      expect(submitted, 4);
      expect(find.text('Your rating: 4/5'), findsOneWidget);
      expect(
        find.text('Could not save your rating. Please retry.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'a saved rating reopens at the previous value and can be changed',
    (tester) async {
      var submitted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppRatingSheet(
              initialRating: 5,
              onSubmit: (stars) async {
                submitted = stars;
                throw const FormatException('keep open');
              },
            ),
          ),
        ),
      );
      expect(find.text('Your rating: 5/5'), findsOneWidget);
      await tester.tap(find.byKey(const Key('app-rating-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('app-rating-submit')));
      await tester.pumpAndSettle();
      expect(submitted, 2);
    },
  );
  testWidgets('Arabic rating labels and five controls fit a small screen', (
    tester,
  ) async {
    AppLanguage.code.value = 'ar';
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LanguageScope(child: const Scaffold(body: AppRatingSheet())),
      ),
    );
    expect(find.text('قيّم التطبيق'), findsOneWidget);
    for (var i = 1; i <= 5; i++)
      expect(find.byKey(Key('app-rating-$i')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
