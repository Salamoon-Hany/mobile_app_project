import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'verification_service.dart';

import '../models/phone_number.dart';
export '../models/phone_number.dart';

/// Links a proven phone credential to the signed-in, verified-email identity.
/// This service never signs in or creates a phone-only account.
class PhoneVerificationService {
  PhoneVerificationService({FirebaseAuth? auth, bool? web})
    : _injectedAuth = auth,
      _web = web ?? kIsWeb;
  final FirebaseAuth? _injectedAuth;
  final bool _web;
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;
  User? get currentUser => _auth.currentUser;
  ConfirmationResult? _confirmation;
  String? _verificationId;
  User? _owner;
  String? _phone;
  int _generation = 0;

  void cancel() {
    _generation++;
    _confirmation = null;
    _verificationId = null;
    _owner = null;
    _phone = null;
  }

  void _checkOwner(User owner, int generation) {
    final current = currentUser;
    if (_generation != generation ||
        current == null ||
        current.uid != owner.uid ||
        current.isAnonymous ||
        !current.emailVerified ||
        (current.email ?? '').isEmpty) {
      throw const FormatException(
        'Your session changed. Log in with your verified email and try again.',
      );
    }
  }

  Future<void> _accept(
    User owner,
    UserCredential result,
    int generation,
    String phone,
  ) async {
    _checkOwner(owner, generation);
    if (result.user?.uid != owner.uid || result.user?.phoneNumber != phone) {
      throw const FormatException(
        'The phone could not be linked to this account. Please retry.',
      );
    }
    await owner.reload();
    _checkOwner(owner, generation);
    if (currentUser?.phoneNumber != phone) {
      throw const FormatException(
        'The phone is not verified yet. Please retry.',
      );
    }
    await currentUser!.getIdToken(true);
  }

  /// Returns true only for native automatic verification; otherwise enter SMS.
  Future<bool> send(String input) async {
    final phone = normalizePhone(input);
    cancel();
    final owner = currentUser;
    if (owner == null) {
      throw const FormatException('Verify your email and sign in first.');
    }
    final generation = _generation;
    _checkOwner(owner, generation);
    if ((owner.phoneNumber ?? '').isNotEmpty) {
      throw const FormatException(
        'This account already has a verified mobile number.',
      );
    }
    _owner = owner;
    _phone = phone;
    if (_web) {
      final confirmation = await owner.linkWithPhoneNumber(phone);
      _checkOwner(owner, generation);
      _confirmation = confirmation;
      return false;
    }
    final ready = Completer<bool>();
    void fail(Object error) {
      if (!ready.isCompleted) ready.completeError(error);
    }

    var automaticLinkInProgress = false;
    unawaited(
      _auth
          .verifyPhoneNumber(
            phoneNumber: phone,
            verificationCompleted: (credential) async {
              // Once a manual challenge is shown, keep one explicit confirmation path.
              if (ready.isCompleted || automaticLinkInProgress) return;
              automaticLinkInProgress = true;
              try {
                _checkOwner(owner, generation);
                final result = await owner.linkWithCredential(credential);
                await _accept(owner, result, generation, phone);
                if (!ready.isCompleted) ready.complete(true);
              } catch (error) {
                fail(error);
              }
            },
            verificationFailed: fail,
            codeSent: (id, _) {
              try {
                _checkOwner(owner, generation);
                _verificationId = id;
                if (!ready.isCompleted && !automaticLinkInProgress) {
                  ready.complete(false);
                }
              } catch (error) {
                fail(error);
              }
            },
            codeAutoRetrievalTimeout: (id) {
              try {
                _checkOwner(owner, generation);
                _verificationId = id;
                if (!ready.isCompleted && !automaticLinkInProgress) {
                  ready.complete(false);
                }
              } catch (error) {
                fail(error);
              }
            },
          )
          .catchError((Object error) {
            fail(error);
          }),
    );
    return ready.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        cancel();
        throw const FormatException('SMS request timed out. Please retry.');
      },
    );
  }

  Future<void> confirm(String input) async {
    final code = input.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const FormatException('Enter the 6-digit code from your SMS.');
    }
    final owner = _owner;
    final phone = _phone;
    final generation = _generation;
    if (owner == null || phone == null) {
      throw const FormatException('Request an SMS code first.');
    }
    _checkOwner(owner, generation);
    final UserCredential result;
    if (_web && _confirmation != null) {
      result = await _confirmation!.confirm(code);
    } else if (!_web && _verificationId != null) {
      result = await owner.linkWithCredential(
        PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        ),
      );
    } else {
      throw const FormatException('Request a new SMS code first.');
    }
    await _accept(owner, result, generation, phone);
    cancel();
  }

  static String message(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'operation-not-allowed':
        case 'configuration-not-found':
          return 'Enable Phone in Firebase Authentication, then retry. You can continue with email only.';
        case 'billing-not-enabled':
          return 'Real SMS requires Firebase Blaze billing. Continue with email, or use a Firebase Console test number.';
        case 'invalid-phone-number':
          return 'Check the mobile number and country code.';
        case 'invalid-verification-code':
          return 'Incorrect SMS code. Please try again.';
        case 'session-expired':
        case 'code-expired':
        case 'invalid-verification-id':
          return 'This SMS code expired. Request a new code.';
        case 'credential-already-in-use':
          return 'This mobile number belongs to another account. Use a different number.';
        case 'provider-already-linked':
          return 'This account already has a linked mobile number.';
        case 'captcha-check-failed':
        case 'invalid-app-credential':
        case 'missing-app-credential':
          return 'Phone security check failed. Retry reCAPTCHA and check the authorized website domain.';
        case 'sms-region-config-denied':
          return 'SMS is not enabled for this country. Check Firebase SMS region settings.';
      }
    }
    return VerificationService.message(error);
  }
}
