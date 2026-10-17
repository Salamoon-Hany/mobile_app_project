import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/l10n/app_language.dart';
import 'package:mobile_app_project/screens/admin_dashboard.dart';
import 'package:mobile_app_project/screens/auth_gate.dart';
import 'package:mobile_app_project/screens/worker_home.dart';
import 'package:mobile_app_project/screens/dashboard.dart';
import 'package:mobile_app_project/screens/worker_wallet.dart';
import 'package:mobile_app_project/services/marketplace_service.dart';
import 'package:mobile_app_project/widgets/sanad_ui.dart';

void seed({bool admin = true, String role = 'customer'}) {
  Marketplace.shared.apply({
    'isAdmin': admin,
    'account': {
      'uid': 'qa',
      'role': role,
      'name': 'QA',
      'balance': 20000,
      'skills': [],
      'legacy_orders': [],
      'phone': '',
      'contact_phone': '',
      'gender': '',
    },
    'orders': [],
    'withdrawals': [],
    'deposits': [],
  });
}

Map<String, dynamic> dashboard() => {
  'summary': {
    'accounts': 15,
    'customers': 12,
    'workers': 3,
    'registeredThisMonth': 4,
  },
  'jobs': {'total': 7},
  'platform': {
    'balance': 0,
    'demoBalance': 100,
    'monthlyEarnings': 0,
    'monthlyDemoEarnings': 100,
  },
  'registrations': [
    {'month': '2026-10', 'total': 4},
  ],
  'ledger': [],
  'accounts': [],
  'orders': [],
  'applications': [],
  'withdrawals': [],
  'complaints': [],
  'audit': [],
};
Widget app(Widget child) => LanguageScope(
  child: MaterialApp(
    supportedLocales: const [Locale('en'), Locale('ar')],
    locale: Locale(AppLanguage.code.value),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: sanadTheme(Brightness.light),
    home: child,
  ),
);
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.clearAccount();
    AppLanguage.code.value = 'en';
  });
  tearDown(() {
    Marketplace.shared.testTransport = null;
    AppState.clearAccount();
  });
  testWidgets('admin bell opens alerts and marks the selected section read', (
    t,
  ) async {
    Marketplace.shared.isAdmin = true;
    final data = dashboard();
    data['notifications'] = {
      'items': [
        {
          'id': 'order-alert',
          'section': 'Orders',
          'title': 'Order update',
          'body': 'pending',
          'at': 1,
          'read': false,
        },
      ],
      'counts': {'Orders': 1, 'Withdrawals': 1},
      'unreadCount': 2,
    };
    final readSections = <String>[];
    Marketplace.shared.testTransport = (path, body) async {
      if (path == 'admin/notifications/read') {
        readSections.add(body!['section'] as String);
        data['notifications'] = {
          'items': [],
          'counts': {'Orders': 0, 'Withdrawals': 1},
          'unreadCount': 1,
        };
      }
      return data;
    };
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(app(const AdminScreen()));
    await t.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await t.tap(find.byIcon(Icons.notifications_outlined).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Order update'));
    await t.pumpAndSettle();
    expect(readSections, contains('Orders'));
    expect(find.text('2'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('admin lands directly in a standalone UI without an account', (
    t,
  ) async {
    Marketplace.shared.isAdmin = true;
    expect(Marketplace.shared.account, isNull);
    Marketplace.shared.testTransport = (p, b) async => dashboard();
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(app(const AccountHome()));
    await t.pumpAndSettle();
    expect(find.byType(AdminScreen), findsOneWidget);
    expect(find.byType(MyHomePage), findsNothing);
    expect(find.byType(WorkerHome), findsNothing);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(Marketplace.shared.account, isNull);
    expect(t.takeException(), isNull);
  });
  testWidgets('ordinary users cannot open the admin dashboard', (t) async {
    seed(admin: false);
    var requests = 0;
    Marketplace.shared.testTransport = (p, b) async {
      requests++;
      return dashboard();
    };
    addTearDown(() => t.pumpWidget(const SizedBox()));
    await t.pumpWidget(app(const AdminScreen()));
    await t.pump();
    expect(find.text('Access denied'), findsOneWidget);
    expect(requests, 0);
  });
  testWidgets(
    'admin overview and separate platform wallet fit a narrow Arabic screen',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      seed();
      AppLanguage.code.value = 'ar';
      Marketplace.shared.testTransport = (p, b) async => dashboard();
      addTearDown(() => t.pumpWidget(const SizedBox()));
      await t.pumpWidget(app(const AdminScreen()));
      await t.pumpAndSettle();
      expect(find.text('إجمالي الحسابات'), findsWidgets);
      expect(t.takeException(), isNull);
      await t.tap(find.text('محفظة المنصة').first);
      await t.pumpAndSettle();
      expect(find.text('رصيد المنصة'), findsWidgets);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'customer withdrawal shows two percent and worker withdrawal shows eight percent',
    (t) async {
      seed();
      await t.pumpWidget(app(const WorkerWalletScreen()));
      await t.pump();
      expect(find.text('Withdrawal fee (2%)'), findsWidgets);
      await t.pumpWidget(const SizedBox());
      seed(role: 'worker');
      await t.pumpWidget(app(const WorkerWalletScreen()));
      await t.pump();
      expect(find.text('Withdrawal fee (8%)'), findsWidgets);
    },
  );
}
