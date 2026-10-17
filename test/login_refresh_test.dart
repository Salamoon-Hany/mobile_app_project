import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/screens/security_verification.dart';
import 'package:mobile_app_project/services/verification_service.dart';
import 'verification_screen_test.dart' show FakeAuth, FakeUser, FakeCredential;

class PreviouslyVerifiedUser extends FakeUser {
  int verificationEmails = 0;
  @override
  Future<void> reload() async {
    reloads++;
    emailVerified = true;
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    verificationEmails++;
  }
}

class ReturningAuth extends FakeAuth {
  ReturningAuth() : super(user: PreviouslyVerifiedUser());
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    currentUser = user;
    return FakeCredential(user);
  }
}

void main() {
  testWidgets(
    'verified returning user reloads stale status and signs in without another verification email',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final auth = ReturningAuth();
      var completed = false;
      await t.pumpWidget(
        MaterialApp(
          home: EmailAuthScreen(
            service: VerificationService(auth: auth),
            onVerified: () async {
              completed = true;
            },
          ),
        ),
      );
      final fields = find.byType(TextFormField);
      await t.enterText(fields.at(0), 'student@example.com');
      await t.enterText(fields.at(1), 'Password123');
      await t.ensureVisible(find.widgetWithText(FilledButton, 'Log in'));
      await t.tap(find.widgetWithText(FilledButton, 'Log in'));
      await t.pumpAndSettle();
      expect(completed, true);
      expect(auth.user.reloads, 1);
      expect((auth.user as PreviouslyVerifiedUser).verificationEmails, 0);
      expect(find.text('I verified my email'), findsNothing);
    },
  );
  test('phone number is rejected as a login identifier', () {
    expect(
      () => normalizeLoginIdentifier('01012345678'),
      throwsFormatException,
    );
  });
}
