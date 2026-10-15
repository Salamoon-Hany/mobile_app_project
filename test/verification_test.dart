import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile_app_project/services/verification_service.dart';

void main() {
  test('invalid emails are rejected before contacting Firebase', () {
    expect(normalizeEmail(' Student@Example.com '), 'student@example.com');
    for (final input in ['', 'student', 'a@b', 'a b@example.com']) {
      expect(() => normalizeEmail(input), throwsFormatException);
    }
  });
  test('unexpected Firebase errors hide diagnostic details', () {
    final message = VerificationService.message(
      FirebaseAuthException(
        code: 'unexpected-provider-error',
        message: 'password=secret token=private email=private@example.com',
      ),
    );
    expect(message, 'Could not complete this action. Please retry later.');
    expect(message, isNot(contains('secret')));
    expect(message, isNot(contains('private')));
  });
  test('internal setup failures show safe recovery messages', () {
    expect(
      VerificationService.message(
        FirebaseAuthException(code: 'admin-restricted-operation'),
      ),
      contains('Account creation is temporarily unavailable'),
    );
    expect(
      VerificationService.message(
        FirebaseAuthException(code: 'operation-not-allowed'),
      ),
      contains('Sign in is temporarily unavailable'),
    );
    expect(
      VerificationService.message(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      contains('Could not load your account'),
    );
  });
}
