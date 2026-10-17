import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_project/services/account_service.dart';
import 'package:mobile_app_project/services/verification_service.dart';
import 'package:mobile_app_project/screens/security_verification.dart';
import 'package:mobile_app_project/screens/delete_account.dart';

class FakeUser implements User {
  @override
  String get uid => 'signup-test';
  @override
  bool isAnonymous = false;
  @override
  bool emailVerified = false;
  @override
  String? email = 'student@example.com';
  @override
  String? displayName = 'Student';
  @override
  String? phoneNumber;
  bool mailFails = false;
  int tokenRefreshes = 0;
  int reloads = 0;
  @override
  Future<void> updateDisplayName(String? name) async {
    displayName = name;
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    if (mailFails) throw FirebaseAuthException(code: 'network-request-failed');
  }

  @override
  Future<void> reload() async {
    reloads++;
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) tokenRefreshes++;
    return 'refreshed-token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeCredential implements UserCredential {
  FakeCredential(this.user);
  @override
  final User? user;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeAuth implements FirebaseAuth {
  FakeAuth({FakeUser? user}) : user = user ?? FakeUser();
  @override
  User? currentUser;
  final FakeUser user;
  int signups = 0;
  String? receivedEmail;
  String? receivedPassword;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signups++;
    receivedEmail = email;
    receivedPassword = password;
    currentUser = user;
    return FakeCredential(user);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('only non-anonymous accounts with verified email pass the gate', () {
    final user = FakeUser();
    expect(hasVerifiedContact(user), false);
    user.emailVerified = true;
    expect(hasVerifiedContact(user), true);
    user.isAnonymous = true;
    expect(hasVerifiedContact(user), false);
    expect(hasVerifiedContact(null), false);
  });
  test(
    'verification reloads user and refreshes only a verified token',
    () async {
      final auth = FakeAuth();
      auth.currentUser = auth.user;
      final service = VerificationService(auth: auth);
      expect(await service.refreshVerification(), false);
      expect(auth.user.tokenRefreshes, 0);
      auth.user.emailVerified = true;
      expect(await service.refreshVerification(), true);
      expect(auth.user.reloads, 2);
      expect(auth.user.tokenRefreshes, 1);
    },
  );
  testWidgets('unconfigured email stays locked without fake OTP or SMS', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EmailAuthScreen()));
    expect(find.textContaining('not set up yet'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('SMS'), findsNothing);
    expect(find.textContaining('Test OTP'), findsNothing);
    expect(find.text('Email or verified mobile number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
  testWidgets('login password visibility preserves typed text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EmailAuthScreen()));
    final password = find.byType(TextFormField).at(1);
    await tester.enterText(password, 'MyPassword123');
    expect(tester.widget<TextFormField>(password).obscureText, isTrue);
    await tester.tap(find.byKey(const Key('toggle-password')));
    await tester.pump();
    expect(tester.widget<TextFormField>(password).obscureText, isFalse);
    expect(
      tester.widget<TextFormField>(password).controller!.text,
      'MyPassword123',
    );
    await tester.tap(find.byKey(const Key('toggle-password')));
    await tester.pump();
    expect(tester.widget<TextFormField>(password).obscureText, isTrue);
  });
  testWidgets('signup confirmation visibility is independent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EmailAuthScreen(action: AccountAction.signup)),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), 'Password123');
    await tester.enterText(fields.at(3), 'Password123');
    final toggle = find.byKey(const Key('toggle-confirm-password'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<TextFormField>(fields.at(3)).obscureText, isFalse);
    expect(tester.widget<TextFormField>(fields.at(2)).obscureText, isTrue);
    expect(
      tester.widget<TextFormField>(fields.at(3)).controller!.text,
      'Password123',
    );
  });
  testWidgets('delete account password can be revealed without losing text', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DeleteAccountScreen()));
    final password = find.byType(TextField);
    await tester.enterText(password, 'Password123');
    await tester.tap(find.byKey(const Key('toggle-password')));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    expect(tester.widget<TextField>(password).controller!.text, 'Password123');
  });
  testWidgets('signup validates confirmation before creating account', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: EmailAuthScreen(
          action: AccountAction.signup,
          service: VerificationService(auth: auth),
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Student');
    await tester.enterText(fields.at(1), 'student@example.com');
    await tester.enterText(fields.at(2), 'StrongPassword123');
    await tester.enterText(fields.at(3), 'DifferentPassword123');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.signups, 0);
  });
  testWidgets(
    'mail failure keeps signup pending; unverified check cannot complete',
    (tester) async {
      final auth = FakeAuth();
      auth.user.mailFails = true;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: EmailAuthScreen(
            action: AccountAction.signup,
            service: VerificationService(auth: auth),
            onVerified: () async {
              completed = true;
            },
          ),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Student');
      await tester.enterText(fields.at(1), ' Student@Example.com ');
      await tester.enterText(fields.at(2), 'StrongPassword123');
      await tester.enterText(fields.at(3), 'StrongPassword123');
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('I verified my email'), findsOneWidget);
      expect(find.text('Resend verification email'), findsOneWidget);
      await tester.tap(find.text('I verified my email'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not verified yet'), findsOneWidget);
      expect(completed, false);
      expect(auth.signups, 1);
      expect(auth.receivedEmail, 'student@example.com');
      expect(auth.receivedPassword, 'StrongPassword123');
      await tester.tap(find.text('Use another account'));
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsOneWidget);
      expect(auth.currentUser, isNull);
    },
  );
}
