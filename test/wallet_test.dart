import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app_project/models/wallet.dart';
import 'package:mobile_app_project/services/wallet_service.dart';
import 'package:mobile_app_project/screens/add_funds.dart';

import 'verification_screen_test.dart' show FakeAuth;
import 'phone_verification_test.dart' show PhoneUser;

void main() {
  test(
    'minimum, decimal validation, Arabic digits and 1% fees use exact piasters',
    () {
      for (final input in [
        '',
        '0',
        '-10',
        '9.99',
        'NaN',
        'Infinity',
        '1e3',
        '10.001',
        '1000001',
      ]) {
        expect(() => DepositQuote.parse(input), throwsFormatException);
      }
      final minimum = DepositQuote.parse('10');
      expect(minimum.feePiasters, 10);
      expect(minimum.totalPiasters, 1010);
      final quote = DepositQuote.parse('١٠٠٫٠٠');
      expect(quote.amountPiasters, 10000);
      expect(quote.feePiasters, 100);
      expect(quote.totalPiasters, 10100);
      expect(DepositQuote.parse('10.50').feePiasters, 11);
    },
  );
  test('demo credits amount only once and clears on account switch', () async {
    final user = PhoneUser()..emailVerified = true;
    final auth = FakeAuth()..currentUser = user;
    final state = WalletState()..attach(user.uid);
    final service = WalletService(auth: auth, state: state, backendUrl: '');
    final quote = DepositQuote.parse('100');
    final result = await service.begin(quote, DepositMethod.visa, 'request-1');
    await service.begin(quote, DepositMethod.visa, 'request-1');
    expect(state.balancePiasters, 10000);
    expect(result.receipt!.text, contains('Deposit receipt'));
    expect(
      result.receipt!.text,
      isNot(contains('no real payment or email sent')),
    );
    state.attach('another-account');
    expect(state.balancePiasters, 0);
    await expectLater(
      service.begin(quote, DepositMethod.visa, 'request-2'),
      throwsFormatException,
    );
  });
  test(
    'live pending checkout cannot credit balance; logout blocks late response',
    () async {
      final user = PhoneUser()..emailVerified = true;
      final auth = FakeAuth()..currentUser = user;
      final state = WalletState()..attach(user.uid);
      var signOutOnResponse = false;
      final service = WalletService(
        auth: auth,
        state: state,
        backendUrl: 'https://payments.example.invalid',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], startsWith('Bearer '));
          if (signOutOnResponse) await auth.signOut();
          return http.Response(
            jsonEncode({
              'id': 'deposit-1',
              'checkoutUrl': 'https://atfawry.com/test',
            }),
            200,
          );
        }),
      );
      final result = await service.begin(
        DepositQuote.parse('100'),
        DepositMethod.fawry,
        'request-1',
      );
      expect(result.receipt, isNull);
      expect(state.balancePiasters, 0);
      signOutOnResponse = true;
      await expectLater(
        service.begin(
          DepositQuote.parse('100'),
          DepositMethod.fawry,
          'request-2',
        ),
        throwsFormatException,
      );
      expect(state.balancePiasters, 0);
    },
  );
  testWidgets('under 10 rejected; 100 shows 101 and confirms demo credit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final user = PhoneUser()..emailVerified = true;
    final auth = FakeAuth()..currentUser = user;
    final state = WalletState()..attach(user.uid);
    final service = WalletService(auth: auth, state: state, backendUrl: '');
    await tester.pumpWidget(
      MaterialApp(home: AddFundsScreen(service: service)),
    );
    expect(find.text('Balance: EGP 0.00'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<DepositMethod>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VISA').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('deposit-amount')), '9');
    await tester.tap(find.widgetWithText(FilledButton, 'Add funds'));
    await tester.pumpAndSettle();
    expect(find.text('Minimum deposit is 10 pounds.'), findsOneWidget);
    expect(state.balancePiasters, 0);
    await tester.enterText(find.byKey(const Key('deposit-amount')), '100');
    await tester.pump();
    expect(find.text('EGP 101.00'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add funds'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm deposit'));
    await tester.pumpAndSettle();
    expect(state.balancePiasters, 10000);
    expect(find.text('Deposit added'), findsOneWidget);
    expect(find.textContaining('not sent.'), findsNothing);
    expect(find.textContaining('Deposit receipt'), findsOneWidget);
  });
}
