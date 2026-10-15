import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/l10n/app_language.dart';
import 'package:mobile_app_project/screens/security_verification.dart';
import 'package:mobile_app_project/screens/worker_home.dart';
import 'package:mobile_app_project/screens/dashboard.dart';
import 'package:mobile_app_project/services/account_service.dart';
import 'package:mobile_app_project/services/marketplace_service.dart';
import 'package:mobile_app_project/models/wallet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLanguage.code.value = 'en';
    AppState.clearAccount();
    WalletState.shared.attach('worker-test');
  });
  tearDown(AppState.clearAccount);
  testWidgets(
    'signup distinguishes customer and worker, login keeps one identity field',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: EmailAuthScreen(action: AccountAction.signup)),
      );
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Worker'), findsOneWidget);
      await tester.tap(find.text('Worker'));
      await tester.pump();
      final selected = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(selected.selected, {'worker'});
      await tester.pumpWidget(const MaterialApp(home: EmailAuthScreen()));
      expect(find.text('Customer'), findsNothing);
    },
  );
  testWidgets(
    'worker incoming and active tabs show shared orders and decision controls',
    (tester) async {
      Marketplace.shared.apply({
        'account': {
          'uid': 'worker-test',
          'role': 'worker',
          'name': 'Ahmed Salah',
          'skills': ['builder'],
          'balance': 0,
          'photo': null,
          'legacy_orders': [],
        },
        'deposits': [],
        'orders': [
          {
            'id': 'shared-order',
            'services': ['builder'],
            'details': 'Repair wall',
            'status': 'pending',
            'amount': 7500,
            'created_at': 1,
            'updated_at': 1,
            'worker_name': 'Ahmed Salah',
            'customer_name': 'Customer',
            'location': {
              'latitude': 30.04,
              'longitude': 31.2,
              'label': 'Dokki',
            },
            'has_photo': 0,
          },
        ],
      });
      await tester.pumpWidget(const MaterialApp(home: WorkerHome()));
      expect(find.text('Ahmed Salah'), findsOneWidget);
      expect(find.text('Repair wall'), findsOneWidget);
      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      await tester.tap(find.byKey(const Key('worker-filter-1')));
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsNothing);
      expect(find.text('No orders here yet.'), findsOneWidget);
    },
  );
  testWidgets('customer Pending, Active and History match actual decisions', (
    tester,
  ) async {
    final now = DateTime.now();
    OrdersManager.restore([
      for (final state in ['pending', 'accepted', 'rejected'])
        OrderModel(
          id: state,
          service: '$state job',
          description: 'details',
          status: state,
          icon: '🛠️',
          createdAt: now,
          statusChangedAt: now,
        ),
    ]);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OrdersScreen())),
    );
    expect(find.text('pending job'), findsOneWidget);
    expect(find.text('accepted job'), findsNothing);
    await tester.tap(find.text('Active'));
    await tester.pump();
    expect(find.text('accepted job'), findsOneWidget);
    expect(find.text('pending job'), findsNothing);
    await tester.tap(find.text('History'));
    await tester.pump();
    expect(find.text('rejected job'), findsOneWidget);
    expect(find.text('accepted job'), findsNothing);
  });
}
