import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app_project/services/phone_login_service.dart';
import 'package:mobile_app_project/services/verification_service.dart';

import 'verification_screen_test.dart' show FakeAuth, FakeUser, FakeCredential;

class LinkedUser extends FakeUser {
  @override
  String get uid => 'same-uid';
}

class LoginAuth extends FakeAuth {
  LoginAuth()
    : super(
        user: LinkedUser()
          ..emailVerified = true
          ..phoneNumber = '+201012345678',
      );
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    receivedEmail = email;
    receivedPassword = password;
    currentUser = user;
    return FakeCredential(user);
  }
}

void main() {
  test(
    'phone/password signs in to the existing email account and UID',
    () async {
      final auth = LoginAuth();
      final service = PhoneLoginService(
        base: Uri.parse('https://sanad.test'),
        client: MockClient((request) async {
          expect(request.url.path, '/api/auth/phone/login');
          expect(jsonDecode(request.body), {
            'phone': '+201012345678',
            'password': 'the password',
          });
          return http.Response(
            jsonEncode({'uid': 'same-uid', 'email': 'person@example.com'}),
            200,
          );
        }),
      );
      await VerificationService(
        auth: auth,
        phoneLogin: service,
      ).logIn('٠١٠١٢٣٤٥٦٧٨', 'the password');
      expect(auth.receivedEmail, 'person@example.com');
      expect(auth.receivedPassword, 'the password');
      expect(auth.currentUser?.uid, 'same-uid');
      service.dispose();
    },
  );
  test(
    'phone mismatch after password verification signs the session out',
    () async {
      final auth = LoginAuth();
      auth.user.phoneNumber = '+201099999999';
      final service = PhoneLoginService(
        base: Uri.parse('https://sanad.test'),
        client: MockClient(
          (_) async => http.Response(
            '{"uid":"same-uid","email":"person@example.com"}',
            200,
          ),
        ),
      );
      await expectLater(
        VerificationService(
          auth: auth,
          phoneLogin: service,
        ).logIn('01012345678', 'the password'),
        throwsFormatException,
      );
      expect(auth.currentUser, isNull);
      service.dispose();
    },
  );
  test('mobile sign-in cannot use an insecure remote endpoint', () async {
    final service = PhoneLoginService(
      base: Uri.parse('http://remote.test'),
      client: MockClient(
        (_) async => throw StateError('must not send credentials'),
      ),
    );
    await expectLater(
      service.resolve('01012345678', 'secret'),
      throwsFormatException,
    );
    service.dispose();
  });
}
