import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/services/local_account_store.dart';
import 'package:mobile_app_project/services/account_service.dart';
import 'package:mobile_app_project/screens/dashboard.dart';
import 'package:mobile_app_project/models/wallet.dart';
import 'package:mobile_app_project/models/selected_location.dart';

import 'dart:typed_data';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalAccountStore.initialize();
  });
  setUp(AppState.clearAccount);
  tearDown(AppState.clearAccount);
  void attach(String uid) {
    AccountService.activeUid = uid;
    WalletState.shared.attach(uid);
    LocalAccountStore.restore(uid);
  }

  test(
    'same account restores balance and orders after logout and restart',
    () async {
      attach('persist-a');
      WalletState.shared.creditDemo(
        'persist-a',
        DepositReceipt(
          id: 'deposit-a',
          quote: DepositQuote(20000),
          method: DepositMethod.visa,
          email: 'a@example.com',
          demo: true,
        ),
      );
      OrdersManager.restore([
        OrderModel(
          id: 'order-a',
          service: 'Electrician',
          description: 'My address',
          status: 'pending',
          icon: '🔌',
          createdAt: DateTime(2026),
          statusChangedAt: DateTime(2026),
        ),
      ]);
      await LocalAccountStore.flush();
      AppState.clearAccount();
      expect(WalletState.shared.balancePiasters, 0);
      expect(OrdersManager.getOrders(), isEmpty);
      attach('persist-a');
      expect(WalletState.shared.balancePiasters, 20000);
      expect(OrdersManager.getOrders().single.id, 'order-a');
    },
  );
  test(
    'profile photo survives sign-out and stays isolated by account',
    () async {
      attach('photo-owner');
      AppState.setUserProfileImageBytes(Uint8List.fromList([1, 2, 3, 4]));
      await LocalAccountStore.flush();
      AppState.clearAccount();
      attach('photo-other');
      expect(AppState.getUserProfileImageBytes(), isNull);
      AppState.clearAccount();
      attach('photo-owner');
      expect(AppState.getUserProfileImageBytes(), orderedEquals([1, 2, 3, 4]));
    },
  );
  test(
    'accounts remain isolated and duplicate receipts survive restore',
    () async {
      attach('persist-a');
      final receipt = DepositReceipt(
        id: 'deposit-a',
        quote: DepositQuote(20000),
        method: DepositMethod.visa,
        email: 'a@example.com',
        demo: true,
      );
      WalletState.shared.creditDemo('persist-a', receipt);
      expect(WalletState.shared.balancePiasters, 20000);
      AppState.clearAccount();
      attach('persist-b');
      expect(WalletState.shared.balancePiasters, 0);
      expect(OrdersManager.getOrders(), isEmpty);
      WalletState.shared.setBalance(3000);
      await LocalAccountStore.flush();
      AppState.clearAccount();
      attach('persist-a');
      expect(WalletState.shared.balancePiasters, 20000);
    },
  );
  test('unfinished reserved booking is refunded on restart', () async {
    attach('reservation');
    WalletState.shared.setBalance(10000);
    BookingState.selectedJobs = [jobCatalog.first];
    BookingState.selectedLocation = const SelectedLocation(
      latitude: 30,
      longitude: 31,
      label: 'Giza',
    );
    BookingState.selectWorker(
      const Worker(
        id: '1',
        name: 'Worker',
        image: '',
        jobsCompleted: 1,
        rating: 5,
      ),
    );
    BookingState.reservePayment();
    await LocalAccountStore.flush();
    // Restore the durable snapshot while the old in-memory draft is gone.
    WalletState.shared.attach('temporary');
    BookingState.reset();
    AccountService.activeUid = 'reservation';
    WalletState.shared.attach('reservation');
    LocalAccountStore.restore('reservation');
    expect(WalletState.shared.balancePiasters, 10000);
    expect(BookingState.paymentCompleted, isFalse);
  });
}
