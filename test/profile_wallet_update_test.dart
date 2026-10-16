import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/l10n/app_language.dart';
import 'package:mobile_app_project/models/profile_completion.dart';
import 'package:mobile_app_project/screens/dashboard.dart';
import 'package:mobile_app_project/screens/app_rating.dart';
import 'package:mobile_app_project/screens/security_verification.dart';
import 'package:mobile_app_project/screens/delete_account.dart';
import 'package:mobile_app_project/screens/worker_wallet.dart';
import 'package:mobile_app_project/services/marketplace_service.dart';

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
  test(
    'customer completion follows 40, 60, 80, 100 and worker ID is the sixth item',
    () {
      int customer({
        String phone = '',
        String gender = '',
        bool photo = false,
      }) => profileCompletion(
        name: 'Eslam',
        email: 'e@example.com',
        phone: phone,
        gender: gender,
        hasPhoto: photo,
      );
      expect(customer(), 40);
      expect(customer(phone: '01012345678'), 60);
      expect(customer(phone: '01012345678', gender: 'Male'), 80);
      expect(customer(phone: '01012345678', gender: 'Male', photo: true), 100);
      expect(
        profileCompletion(
          name: 'Ahmed',
          email: 'a@example.com',
          phone: '01012345678',
          gender: 'Male',
          hasPhoto: true,
          worker: true,
        ),
        83,
      );
      expect(
        profileCompletion(
          name: 'Ahmed',
          email: 'a@example.com',
          phone: '01012345678',
          gender: 'Male',
          hasPhoto: true,
          worker: true,
          hasId: true,
        ),
        100,
      );
    },
  );
  test(
    'ID accepts Arabic digits, checks real birth dates and never calls identity verified',
    () {
      expect(nationalIdError('٣٠٥٠٩٢٠٠١١٢٣٤٥'), null);
      expect(normalizeNationalId('٣٠٥٠٩٢٠٠١١٢٣٤٥'), '30509200112345');
      expect(nationalIdError(''), null);
      for (final v in ['123', '30502300112345', '39901010112345']) {
        expect(nationalIdError(v), isNotNull);
      }
    },
  );
  test('withdrawal fee uses 5 percent rounded to a piaster', () {
    expect(withdrawalFee(10000), 500);
    expect(withdrawalFee(1010), 51);
    expect(withdrawalFee(1001), 50);
  });
  testWidgets('rating submits optional feedback, including an empty comment', (
    t,
  ) async {
    final received = <String>[];
    Future<void> open() async {
      await t.pumpWidget(const SizedBox());
      await t.pump();
      await t.pumpWidget(
        MaterialApp(
          home: AppRatingSheet(
            onFeedback: (stars, comment) async {
              expect(stars, 5);
              received.add(comment);
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('app-rating-5')));
      await t.pump();
    }

    await open();
    await t.enterText(
      find.byKey(const Key('app-rating-comment')),
      '  Improve search  ',
    );
    await t.ensureVisible(find.byKey(const Key('app-rating-submit')));
    await t.tap(find.byKey(const Key('app-rating-submit')));
    await t.pumpAndSettle();
    expect(received, ['Improve search']);
    await open();
    await t.ensureVisible(find.byKey(const Key('app-rating-submit')));
    await t.tap(find.byKey(const Key('app-rating-submit')));
    await t.pumpAndSettle();
    expect(received, ['Improve search', '']);
  });
  testWidgets(
    'auth pages expose a persisted language choice on the physical right',
    (t) async {
      await AppLanguage.initialize();
      await t.pumpWidget(
        LanguageScope(
          child: ValueListenableBuilder<String>(
            valueListenable: AppLanguage.code,
            builder: (_, code, __) => MaterialApp(
              home: Directionality(
                textDirection: code == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: const EmailAuthScreen(),
              ),
            ),
          ),
        ),
      );
      final button = find.byKey(const Key('auth-language'));
      expect(button, findsOneWidget);
      expect(t.getCenter(button).dx, greaterThan(400));
      await t.tap(button);
      await t.pumpAndSettle();
      await t.tap(find.text('العربية'));
      await t.pumpAndSettle();
      expect(AppLanguage.code.value, 'ar');
      expect(t.getCenter(button).dx, greaterThan(400));
      expect(
        (await SharedPreferences.getInstance()).getString('sanad.language.v1'),
        'ar',
      );
    },
  );
  testWidgets(
    'both profiles have delete action, plain phone, and worker-only optional ID',
    (t) async {
      AppState.setUserName('Eslam');
      AppState.setUserEmail('e@example.com');
      await t.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await t.pumpAndSettle();
      expect(find.text('40%'), findsOneWidget);
      expect(find.byKey(const Key('profile-phone')), findsOneWidget);
      expect(find.text('Send SMS code'), findsNothing);
      expect(find.byKey(const Key('profile-national-id')), findsNothing);
      await t.scrollUntilVisible(
        find.byKey(const Key('profile-delete-account')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Delete Account'), findsOneWidget);
      Marketplace.shared.account = {
        'role': 'worker',
        'national_id_last4': '2345',
      };
      await t.pumpWidget(
        const MaterialApp(home: ProfileScreen(key: ValueKey('worker'))),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('profile-national-id')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('profile-national-id')), findsOneWidget);
      await t.scrollUntilVisible(
        find.byKey(const Key('profile-delete-account')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Delete Account'), findsOneWidget);
    },
  );
  testWidgets(
    'delete requires acknowledgement and password and explains balance loss',
    (t) async {
      await t.pumpWidget(const MaterialApp(home: DeleteAccountScreen()));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Any remaining balance will be lost'),
        findsOneWidget,
      );
      final button = find.widgetWithText(FilledButton, 'Delete Account');
      expect(t.widget<FilledButton>(button).onPressed, null);
      await t.enterText(find.byType(TextField), 'secret');
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      expect(t.widget<FilledButton>(button).onPressed, isNotNull);
    },
  );
  testWidgets(
    'worker withdrawal previews gross, 5 percent fee and net before submission',
    (t) async {
      Marketplace.shared.account = {'role': 'worker', 'balance': 10000};
      await t.pumpWidget(const MaterialApp(home: WorkerWalletScreen()));
      await t.enterText(find.byKey(const Key('withdraw-amount')), '100');
      await t.enterText(
        find.byKey(const Key('withdraw-destination')),
        '01012345678',
      );
      await t.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Request withdrawal'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.widgetWithText(FilledButton, 'Request withdrawal'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Confirm withdrawal'), findsOneWidget);
      expect(find.text('Withdrawal fee (5%): EGP 5.00'), findsWidgets);
      expect(find.text('You receive: EGP 95.00'), findsWidgets);
      await t.tap(find.text('Back'));
      await t.pumpAndSettle();
      expect(Marketplace.shared.account!['balance'], 10000);
      expect(Marketplace.shared.withdrawals, isEmpty);
    },
  );
}
