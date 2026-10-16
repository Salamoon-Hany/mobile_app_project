import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/l10n/app_language.dart';
import 'package:mobile_app_project/screens/dashboard.dart';
import 'package:mobile_app_project/screens/worker_home.dart';
import 'package:mobile_app_project/services/marketplace_service.dart';
import 'package:mobile_app_project/widgets/sanad_ui.dart';

const visualQa = bool.fromEnvironment('SANAD_VISUAL_QA');
const rootKey = Key('figma-qa-root');
Future<void> capture(WidgetTester t, String name) async {
  if (!visualQa) return;
  await t.runAsync(() async {
    await Future.wait(
      find
          .byType(Image)
          .evaluate()
          .map((e) => precacheImage((e.widget as Image).image, e)),
    );
  });
  await t.pumpAndSettle();
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(rootKey));
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('../../sanad-ui-qa');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

void seed(String role, {String name = 'Ahmed Salah'}) {
  Marketplace.shared.apply({
    'account': {
      'uid': 'qa-only',
      'role': role,
      'name': name,
      'balance': 12000,
      'skills': role == 'worker' ? ['builder', 'electrician'] : [],
      'photo': null,
      'legacy_orders': [],
      'phone': '',
      'contact_phone': '',
      'gender': '',
      'national_id_last4': '',
    },
    'deposits': [],
    'orders': [
      {
        'id': 'qa-order',
        'services': ['builder'],
        'details': 'Repair the entrance wall',
        'status': 'pending',
        'amount': 7500,
        'created_at': 1792047600000,
        'updated_at': 1792047600000,
        'worker_name': 'Ahmed Salah',
        'customer_name': 'Customer',
        'customer_phone': '+201000000000',
        'has_photo': 0,
        'location': {
          'latitude': 30.04,
          'longitude': 31.2,
          'label': 'Dokki',
          'fromGps': false,
        },
      },
    ],
  });
}

Widget app(Widget child, {bool dark = false}) => LanguageScope(
  child: RepaintBoundary(
    key: rootKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(AppLanguage.code.value),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: sanadTheme(dark ? Brightness.dark : Brightness.light),
      home: child,
    ),
  ),
);
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.clearAccount();
    AppLanguage.code.value = 'en';
  });
  tearDown(() {
    AppState.clearAccount();
    AppLanguage.code.value = 'en';
  });
  setUpAll(() async {
    if (visualQa && Platform.isWindows) {
      final f = File(r'C:\Windows\Fonts\arial.ttf');
      if (await f.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(f.readAsBytes().then((v) => ByteData.sublistView(v)));
        await loader.load();
        final material = FontLoader('MaterialIcons')
          ..addFont(
            File(
              r'C:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
            ).readAsBytes().then((v) => ByteData.sublistView(v)),
          );
        await material.load();
      }
    }
  });
  testWidgets(
    'worker reference layout retains details, decisions and wallet navigation',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      seed('worker');
      await t.pumpWidget(app(const WorkerHome()));
      await t.pumpAndSettle();
      expect(find.text('Ahmed Salah'), findsOneWidget);
      expect(find.text('Available for jobs'), findsOneWidget);
      expect(find.text('Worker workspace'), findsNothing);
      expect(find.text('EGP 120.00'), findsOneWidget);
      expect(t.takeException(), isNull);
      await capture(t, 'worker-en');
      await Scrollable.ensureVisible(
        t.element(find.text('View details')),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('View details'));
      await t.pumpAndSettle();
      expect(find.textContaining('Dokki'), findsOneWidget);
      expect(find.text('+201000000000'), findsOneWidget);
      await capture(t, 'worker-order-details');
      await t.tap(find.byKey(const Key('request-back')));
      await t.pumpAndSettle();
      await t.tap(find.text('Jobs'));
      await t.pumpAndSettle();
      await capture(t, 'worker-jobs');
      await t.tap(find.byKey(const Key('worker-filter-1')));
      await t.pumpAndSettle();
      expect(find.text('Accept'), findsNothing);
      expect(find.text('No orders here yet.'), findsOneWidget);
      await t.tap(find.text('Settings'));
      await t.pumpAndSettle();
      await capture(t, 'worker-settings');
      await t.tap(find.byKey(const Key('worker-profile-shortcut')));
      await t.pumpAndSettle();
      await capture(t, 'worker-profile');
      await t.tap(find.byKey(const Key('profile-back')));
      await t.pumpAndSettle();
      await t.tap(find.text('Balance'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('withdraw-amount')), findsOneWidget);
      await capture(t, 'worker-wallet');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Arabic dark worker layout fits narrow mobile screens', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    AppLanguage.code.value = 'ar';
    seed('worker', name: 'أحمد صلاح');
    await t.pumpWidget(app(const WorkerHome(), dark: true));
    await t.pumpAndSettle();
    expect(find.text('أحمد صلاح'), findsOneWidget);
    expect(t.takeException(), isNull);
    await capture(t, 'worker-ar-dark');
  });
  testWidgets(
    'customer reference layout retains original catalogue and status filters',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      seed('customer', name: 'Eslam');
      await t.pumpWidget(app(const MyHomePage()));
      await t.pumpAndSettle();
      expect(find.text('Builder'), findsOneWidget);
      expect(find.text('Cleaning'), findsNothing);
      expect(find.text('Painting'), findsNothing);
      expect(find.text('Air Conditioning'), findsNothing);
      expect(t.takeException(), isNull);
      await capture(t, 'customer-home');
      await t.tap(find.text('Orders'));
      await t.pumpAndSettle();
      expect(find.text('Builder'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
      await capture(t, 'customer-orders');
      await t.tap(find.text('Active'));
      await t.pumpAndSettle();
      expect(find.text('Builder'), findsNothing);
    },
  );
  testWidgets(
    'job search survives tab changes and details react to the server decision',
    (t) async {
      seed('worker');
      await t.pumpWidget(app(const WorkerHome()));
      await t.pumpAndSettle();
      await t.tap(find.text('Jobs'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('worker-job-search')),
        'missing area',
      );
      await t.pumpAndSettle();
      expect(find.text('No orders here yet.'), findsOneWidget);
      await t.tap(find.text('Settings'));
      await t.pumpAndSettle();
      await t.tap(find.text('Jobs'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.byKey(const Key('worker-job-search')))
            .controller!
            .text,
        'missing area',
      );
      await t.enterText(find.byKey(const Key('worker-job-search')), 'Dokki');
      await t.pumpAndSettle();
      await t.tap(find.text('View details'));
      await t.pumpAndSettle();
      expect(find.text('Accept'), findsOneWidget);
      final m = Marketplace.shared;
      final account = Map<String, dynamic>.from(m.account!);
      final order = Map<String, dynamic>.from(m.orders.single)
        ..['status'] = 'accepted';
      m.apply({
        'account': account,
        'orders': [order],
        'deposits': [],
      });
      await t.pumpAndSettle();
      expect(find.text('Accept'), findsNothing);
      await t.scrollUntilVisible(
        find.text('Waiting for the customer to confirm completed work.'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Waiting for the customer to confirm completed work.'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('request-back')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('worker-filter-1')));
      await t.pumpAndSettle();
      expect(find.text('View details'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('failed availability save retains the last confirmed state', (
    t,
  ) async {
    seed('worker');
    Marketplace.shared.account!['available'] = 1;
    await t.pumpWidget(
      app(
        WorkerHome(
          saveAvailability: (_) async => throw const FormatException('offline'),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(Marketplace.shared.account!['available'], 1);
    expect(t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(
      find.text(
        'Could not sync your account. Check your connection and retry.',
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
}
