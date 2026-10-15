import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/l10n/app_language.dart';
import 'package:mobile_app_project/screens/dashboard.dart';
import 'package:mobile_app_project/screens/service_tools.dart';
import 'package:mobile_app_project/services/marketplace_service.dart';
import 'package:mobile_app_project/widgets/sanad_ui.dart';

Map<String, dynamic> detail() => {
  'messages': [],
  'complaints': [],
  'review': null,
  'extras': [],
};
void seed(String role, {String status = 'completed', bool admin = false}) {
  Marketplace.shared.apply({
    'isAdmin': admin,
    'account': {
      'uid': role == 'worker' ? 'worker' : 'customer',
      'role': role,
      'name': 'QA User',
      'balance': 20000,
      'skills': role == 'worker' ? ['builder'] : [],
      'photo': null,
      'legacy_orders': [],
      'contact_phone': '',
      'phone': '',
      'gender': '',
    },
    'deposits': [],
    'orders': [
      {
        'id': 'order-test-001',
        'worker_uid': 'worker',
        'customer_uid': 'customer',
        'services': ['builder'],
        'details': 'Repair wall',
        'status': status,
        'amount': 7500,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'worker_name': 'QA Worker',
        'customer_name': 'QA Customer',
        'has_photo': 0,
        'location': {
          'latitude': 30.0,
          'longitude': 31.0,
          'label': 'Test location',
          'fromGps': false,
        },
      },
    ],
  });
}

Widget app(Widget w) => RepaintBoundary(
  key: const Key('service-qa-root'),
  child: LanguageScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(AppLanguage.code.value),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: sanadTheme(Brightness.light),
      home: w,
    ),
  ),
);
void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('SANAD_VISUAL_QA')) {
      final font = File(r'C:\Windows\Fonts\arial.ttf');
      final loader = FontLoader('Roboto')
        ..addFont(font.readAsBytes().then((v) => ByteData.sublistView(v)));
      await loader.load();
      final icons = File(
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      );
      if (await icons.exists()) {
        final material = FontLoader('MaterialIcons')
          ..addFont(icons.readAsBytes().then((v) => ByteData.sublistView(v)));
        await material.load();
      }
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLanguage.code.value = 'en';
    AppState.clearAccount();
  });
  tearDown(() {
    Marketplace.shared.testTransport = null;
    AppState.clearAccount();
  });
  testWidgets(
    'optional review comment can submit stars alone after completed work',
    (t) async {
      configureServiceView(t);
      seed('customer');
      Map<String, dynamic>? submitted;
      Marketplace.shared.testTransport = (path, body) async {
        if (path.endsWith('/review')) {
          submitted = body;
          return {
            ...detail(),
            'review': {'stars': body!['stars'], 'comment': '', 'has_photo': 0},
          };
        }
        if (path == 'snapshot') throw const FormatException('Offline');
        return detail();
      };
      await t.pumpWidget(
        app(const OrderActivityScreen(orderId: 'order-test-001')),
      );
      await t.pump();
      await t.tap(find.text('Review'));
      await t.pump();
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit review'),
            )
            .onPressed,
        isNull,
      );
      await t.tap(find.byTooltip('5 / 5'));
      await t.pump();
      await captureService(t, 'service-review-form');
      await t.tap(find.text('Submit review'));
      await t.pump();
      await t.pump();
      expect(submitted?['stars'], 5);
      expect(submitted?['comment'], '');
      expect(find.text('5 / 5'), findsOneWidget);
      await captureService(t, 'service-review');
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'worker cannot submit customer review and closed chat is read only',
    (t) async {
      configureServiceView(t);
      seed('worker');
      Marketplace.shared.testTransport = (p, b) async => detail();
      await t.pumpWidget(
        app(const OrderActivityScreen(orderId: 'order-test-001')),
      );
      await t.pump();
      expect(
        find.text('This conversation is read-only after the order closes.'),
        findsOneWidget,
      );
      expect(find.text('Send'), findsNothing);
      await t.tap(find.text('Review'));
      await t.pump();
      expect(find.text('Submit review'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed chat preserves text and retry uses the same message reference',
    (t) async {
      configureServiceView(t);
      seed('customer', status: 'accepted');
      final ids = <String>[];
      Marketplace.shared.testTransport = (p, b) async {
        if (p.endsWith('/message')) {
          ids.add(b!['requestId'] as String);
          throw const FormatException('Offline');
        }
        return detail();
      };
      await t.pumpWidget(
        app(const OrderActivityScreen(orderId: 'order-test-001')),
      );
      await t.pump();
      await t.enterText(find.byType(TextField).first, 'Hello worker');
      await t.tap(find.text('Send'));
      await t.pump();
      await t.pump();
      expect(find.text('Hello worker'), findsOneWidget);
      await t.tap(find.text('Send'));
      await t.pump();
      await t.pump();
      expect(ids.length, 2);
      expect(ids[0], ids[1]);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('admin entry is hidden for ordinary accounts', (t) async {
    seed('customer');
    await t.pumpWidget(app(const Scaffold(body: ServiceTools())));
    expect(find.text('Admin panel'), findsNothing);
    seed('customer', admin: true);
    await t.pumpWidget(app(const Scaffold(body: ServiceTools())));
    await t.pump();
    expect(find.text('Admin panel'), findsOneWidget);
  });
  testWidgets(
    'Arabic empty quotes and administration tabs render without overflow',
    (t) async {
      configureServiceView(t);
      seed('customer');
      AppLanguage.code.value = 'ar';
      await t.pumpWidget(app(const QuotesScreen()));
      expect(find.text('عروض الأسعار'), findsOneWidget);
      await captureService(t, 'quotes-ar');
      expect(t.takeException(), isNull);
    },
  );
}

Future<void> captureService(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('SANAD_VISUAL_QA')) return;
  await t.pumpAndSettle();
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('service-qa-root')),
    );
    final img = await boundary.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('../../sanad-ui-qa');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    img.dispose();
  });
}

void configureServiceView(WidgetTester t) {
  if (!const bool.fromEnvironment('SANAD_VISUAL_QA')) return;
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}
