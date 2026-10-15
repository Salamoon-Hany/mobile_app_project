import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_project/services/phone_verification_service.dart';
import 'package:mobile_app_project/screens/phone_verification.dart';
import 'package:mobile_app_project/screens/security_verification.dart';
import 'package:mobile_app_project/services/verification_service.dart';
import 'package:mobile_app_project/services/account_service.dart';

import 'verification_screen_test.dart' show FakeUser, FakeAuth, FakeCredential;

class PhoneUser extends FakeUser {
  @override
  String get uid => 'email-account';
  @override
  String? phoneNumber;
  final challenge = FakeConfirmation();
  int requests = 0;
  @override
  Future<ConfirmationResult> linkWithPhoneNumber(
    String phone, [
    RecaptchaVerifier? verifier,
  ]) async {
    requests++;
    challenge.user = this;
    challenge.phone = phone;
    return challenge;
  }
}

class FakeConfirmation implements ConfirmationResult {
  late PhoneUser user;
  late String phone;
  int attempts = 0;
  @override
  Future<UserCredential> confirm(String code) async {
    attempts++;
    if (code != '654321')
      throw FirebaseAuthException(code: 'invalid-verification-code');
    user.phoneNumber = phone;
    return FakeCredential(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class ScreenService extends PhoneVerificationService {
  int sends = 0;
  int confirms = 0;
  bool cancelled = false;
  @override
  Future<bool> send(String input) async {
    sends++;
    return false;
  }

  @override
  Future<void> confirm(String input) async {
    confirms++;
    if (input != '654321')
      throw FirebaseAuthException(code: 'invalid-verification-code');
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Egyptian and international numbers normalize; invalid input is rejected',
    () {
      expect(normalizePhone('010 1234 5678'), '+201012345678');
      expect(normalizePhone('0020-1012345678'), '+201012345678');
      expect(normalizePhone('+44 (7700) 900123'), '+447700900123');
      for (final input in ['123456', 'hello', '+01234567890', '011234567890']) {
        expect(() => normalizePhone(input), throwsFormatException);
      }
    },
  );
  test(
    'no phone request without an authenticated verified-email account',
    () async {
      final auth = FakeAuth();
      final service = PhoneVerificationService(auth: auth, web: true);
      await expectLater(service.send('01012345678'), throwsFormatException);
      final user = PhoneUser();
      auth.currentUser = user;
      await expectLater(service.send('01012345678'), throwsFormatException);
      expect(user.requests, 0);
    },
  );
  test(
    'wrong code stays unverified; correct code links the same email identity',
    () async {
      final auth = FakeAuth();
      final user = PhoneUser()..emailVerified = true;
      auth.currentUser = user;
      final service = PhoneVerificationService(auth: auth, web: true);
      expect(await service.send('01012345678'), false);
      await expectLater(
        service.confirm('111111'),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(user.phoneNumber, isNull);
      expect(auth.currentUser!.uid, 'email-account');
      await service.confirm('654321');
      expect(auth.currentUser!.uid, 'email-account');
      expect(auth.currentUser!.email, 'student@example.com');
      expect(user.phoneNumber, '+201012345678');
      expect(user.tokenRefreshes, 1);
      expect(auth.signups, 0);
    },
  );
  test(
    'logout or cancellation invalidates pending SMS before confirmation',
    () async {
      final auth = FakeAuth();
      final user = PhoneUser()..emailVerified = true;
      auth.currentUser = user;
      final service = PhoneVerificationService(auth: auth, web: true);
      await service.send('01012345678');
      auth.currentUser = null;
      await expectLater(service.confirm('654321'), throwsFormatException);
      expect(user.challenge.attempts, 0);
      auth.currentUser = user;
      await service.send('01012345678');
      service.cancel();
      await expectLater(service.confirm('654321'), throwsFormatException);
      expect(user.phoneNumber, isNull);
    },
  );
  testWidgets(
    'phone step keeps wrong codes pending and prevents immediate resend',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ScreenService();
      await tester.pumpWidget(
        MaterialApp(home: PhoneVerificationScreen(service: service)),
      );
      await tester.enterText(find.byType(TextField).first, '01012345678');
      await tester.tap(find.text('Send SMS code'));
      await tester.pump();
      expect(service.sends, 1);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField).at(1), '111111');
      await tester.tap(find.text('Verify mobile'));
      await tester.pump();
      expect(
        find.text('Incorrect SMS code. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Continue with email only'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(service.cancelled, true);
    },
  );
  testWidgets('email confirmation completes registration without an SMS step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final user = PhoneUser();
    final auth = FakeAuth(user: user);
    final phone = ScreenService();
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EmailAuthScreen(
          action: AccountAction.signup,
          service: VerificationService(auth: auth),
          phoneService: phone,
          onVerified: () async {
            completed = true;
          },
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Student');
    await tester.enterText(fields.at(1), 'student@example.com');
    await tester.enterText(fields.at(2), 'StrongPassword123');
    await tester.enterText(fields.at(3), 'StrongPassword123');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Add your mobile'), findsNothing);
    user.emailVerified = true;
    await tester.tap(find.text('I verified my email'));
    await tester.pumpAndSettle();
    expect(find.text('Add your mobile'), findsNothing);
    expect(completed, true);
    expect(phone.sends, 0);
  });
  testWidgets('email-only continuation sends no SMS', (tester) async {
    final service = ScreenService();
    PhoneStepResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<PhoneStepResult>(
                  MaterialPageRoute(
                    builder: (_) => PhoneVerificationScreen(service: service),
                  ),
                );
              },
              child: const Text('Open phone step'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open phone step'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with email only'));
    await tester.tap(find.text('Continue with email only'));
    await tester.pumpAndSettle();
    expect(result, PhoneStepResult.skipped);
    expect(service.sends, 0);
    expect(service.confirms, 0);
  });
}
