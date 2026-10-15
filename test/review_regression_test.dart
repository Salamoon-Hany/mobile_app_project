import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app_project/models/profile_validation.dart';
import 'package:mobile_app_project/models/selected_location.dart';
import 'package:mobile_app_project/models/wallet.dart';
import 'package:mobile_app_project/screens/dashboard.dart';

class DeferredPicker implements ImagePicker {
  final result = Completer<XFile?>();
  ImageSource? requestedSource;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    requestedSource = invocation.namedArguments[#source] as ImageSource?;
    return result.future;
  }
}

void prepareBooking() {
  BookingState.selectedJobs = [jobCatalog.first];
  BookingState.selectWorker(
    const Worker(
      id: '1',
      name: 'Worker',
      image: '👨‍🔧',
      jobsCompleted: 1,
      rating: 4.5,
    ),
  );
  BookingState.selectedLocation = const SelectedLocation(
    latitude: 30.04,
    longitude: 31.21,
    label: 'Dokki',
  );
}

void main() {
  setUp(() {
    AppState.clearAccount();
    AppState.setDarkMode(false);
    WalletState.shared.attach('student');
    WalletState.shared.setBalance(30000);
  });
  tearDown(AppState.clearAccount);

  test(
    'booking payment is reserved once and refunded only for a discarded draft',
    () {
      prepareBooking();
      BookingState.reservePayment();
      BookingState.reservePayment();
      expect(WalletState.shared.balancePiasters, 22500);
      expect(BookingState.canAfford(), true);
      expect(() => BookingState.addJob(jobCatalog[1]), throwsStateError);
      BookingState.reset();
      BookingState.reset();
      expect(WalletState.shared.balancePiasters, 30000);
    },
  );
  test(
    'completed order consumes its reservation; another account cannot inherit a refund',
    () {
      prepareBooking();
      BookingState.reservePayment();
      BookingState.consumePayment();
      BookingState.reset();
      expect(WalletState.shared.balancePiasters, 22500);
      prepareBooking();
      BookingState.reservePayment();
      WalletState.shared.attach('another');
      BookingState.reset();
      expect(WalletState.shared.balancePiasters, 0);
    },
  );
  test(
    'shared service IDs prevent duplicates and totals sum actual prices',
    () {
      for (final name in ['Steel Fixer', 'Heavy Equipment']) {
        final job = jobCatalog.firstWhere((j) => j.name == name);
        BookingState.addJob(job);
        BookingState.addJob(job);
      }
      expect(BookingState.selectedJobs.length, 2);
      BookingState.selectedJobs = [
        Job(id: 'a', name: 'A', price: 75),
        Job(id: 'b', name: 'B', price: 100.25),
      ];
      expect(BookingState.totalPiasters, 17525);
      expect(() => BookingState.selectedJobs.clear(), throwsUnsupportedError);
      expect(
        () => Job(id: 'bad', name: 'Bad', price: double.infinity),
        throwsFormatException,
      );
    },
  );
  test('profile validation agrees with server name and gender limits', () {
    expect(validateProfileName(' Student '), isNull);
    expect(validateProfileName('a'), isNotNull);
    expect(validateProfileName('a' * 80), isNull);
    expect(validateProfileName('a' * 81), isNotNull);
    expect(
      () => validateProfile(name: 'Student', gender: 'Other'),
      returnsNormally,
    );
    expect(
      () => validateProfile(name: 'Student', gender: 'invalid'),
      throwsFormatException,
    );
  });
  testWidgets(
    'reviewing a selected worker never debits before server confirmation',
    (tester) async {
      prepareBooking();
      await tester.pumpWidget(const MaterialApp(home: BookingPaymentScreen()));
      expect(find.text('Pay and send invite'), findsOneWidget);
      expect(WalletState.shared.balancePiasters, 30000);
      await tester.pumpWidget(const SizedBox());
      expect(WalletState.shared.balancePiasters, 30000);
    },
  );
  testWidgets(
    'no workers shows an empty state without inventing people or taking money',
    (tester) async {
      prepareBooking();
      BookingState.selectedWorker = null;
      await tester.pumpWidget(const MaterialApp(home: BookingPaymentScreen()));
      await tester.pumpAndSettle();
      expect(
        find.text('No workers are available for these services yet.'),
        findsOneWidget,
      );
      expect(find.text('Mahmoud Mohammad'), findsNothing);
      expect(find.text('Select worker'), findsNothing);
      expect(find.text('Pay and send invite'), findsNothing);
      expect(WalletState.shared.balancePiasters, 30000);
    },
  );
  testWidgets('Orders removes its listener when disposed', (tester) async {
    // Inspect Flutter's protected listener flag only to detect the lifecycle leak.
    // ignore: invalid_use_of_protected_member
    expect(OrdersManager.notifier.hasListeners, false);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OrdersScreen())),
    );
    // ignore: invalid_use_of_protected_member
    expect(OrdersManager.notifier.hasListeners, true);
    await tester.pumpWidget(const SizedBox());
    // Inspect Flutter's protected listener flag only to detect the lifecycle leak.
    // ignore: invalid_use_of_protected_member
    expect(OrdersManager.notifier.hasListeners, false);
  });
  testWidgets(
    'profile typing does not save a draft name or accept overlong names',
    (tester) async {
      AppState.setUserName('Saved Student');
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.enterText(find.byType(TextField).first, 'Draft Student');
      expect(AppState.getUserName(), 'Saved Student');
      await tester.enterText(find.byType(TextField).first, 'a' * 81);
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(find.text('Enter 2–80 characters.'), findsOneWidget);
      expect(AppState.getUserName(), 'Saved Student');
    },
  );
  testWidgets(
    'profile photo uses bytes on every platform and a disposed picker cannot update state',
    (tester) async {
      final bytes = Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aU1sAAAAASUVORK5CYII=',
        ),
      );
      AppState.setUserProfileImageBytes(bytes);
      final picker = DeferredPicker();
      await tester.pumpWidget(MaterialApp(home: ProfileScreen(picker: picker)));
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
        isA<MemoryImage>(),
      );
      await tester.tap(find.byType(CircleAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload a Picture'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      picker.result.complete(XFile.fromData(bytes, name: 'photo.png'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(AppState.getUserProfileImageBytes(), same(bytes));
    },
  );
  testWidgets(
    'Take a Picture requests the native camera and cancellation keeps the saved image',
    (tester) async {
      final picker = DeferredPicker();
      await tester.pumpWidget(MaterialApp(home: ProfileScreen(picker: picker)));
      await tester.tap(find.byType(CircleAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a Picture'));
      await tester.pumpAndSettle();
      expect(picker.requestedSource, ImageSource.camera);
      picker.result.complete(null);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(AppState.getUserProfileImageBytes(), isNull);
    },
  );
  testWidgets(
    'Settings reads shared dark mode rather than resetting its switch',
    (tester) async {
      AppState.setDarkMode(true);
      await tester.pumpWidget(const MaterialApp(home: MyHomePage()));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, true);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(AppState.darkMode.value, false);
    },
  );
}
