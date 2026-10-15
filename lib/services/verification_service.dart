import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/phone_number.dart';
import 'phone_login_service.dart';

String normalizeLoginIdentifier(String input) =>
    input.contains('@') ? normalizeEmail(input) : normalizePhone(input);

String normalizeEmail(String input) {
  final email = input.trim().toLowerCase();
  if (email.length > 254 ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    throw const FormatException('Enter a valid email address.');
  }
  return email;
}

class VerificationService {
  VerificationService({FirebaseAuth? auth, PhoneLoginService? phoneLogin})
    : _injectedAuth = auth,
      _phoneLogin = phoneLogin;
  final FirebaseAuth? _injectedAuth;
  final PhoneLoginService? _phoneLogin;
  static bool get configured => Firebase.apps.isNotEmpty;
  bool get available => _injectedAuth != null || configured;
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;
  User? get currentUser => available ? _auth.currentUser : null;

  Future<void> signUp(String email, String password, String name) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: normalizeEmail(email),
      password: password,
    );
    await result.user!.updateDisplayName(name.trim());
  }

  Future<void> logIn(String email, String password) async {
    if (!email.contains('@')) {
      final phone = normalizePhone(email);
      final service = _phoneLogin ?? PhoneLoginService();
      try {
        final account = await service.resolve(phone, password);
        final result = await _auth.signInWithEmailAndPassword(
          email: account.email,
          password: password,
        );
        final user = result.user;
        if (user == null ||
            user.uid != account.uid ||
            user.phoneNumber != phone ||
            !user.emailVerified ||
            user.isAnonymous) {
          await _auth.signOut();
          throw const FormatException(
            'Email or mobile number and password are incorrect.',
          );
        }
      } finally {
        if (_phoneLogin == null) service.dispose();
      }
      return;
    }
    await _auth.signInWithEmailAndPassword(
      email: normalizeEmail(email),
      password: password,
    );
  }

  Future<void> sendVerification() async {
    final user = currentUser;
    if (user == null) throw StateError('Sign in first.');
    await user.sendEmailVerification();
  }

  Future<bool> refreshVerification() async {
    await currentUser?.reload();
    final user = currentUser;
    if (user == null || !user.emailVerified) return false;
    await user.getIdToken(true);
    return true;
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: normalizeEmail(email));
  Future<void> signOut() => _auth.signOut();

  static String message(Object error) {
    if (error is FormatException) return error.message;
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'This email already has an account. Choose Log in.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Choose a stronger password that meets the project password policy.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Email or password is incorrect. Sign up if you need an account.';
        case 'user-disabled':
          return 'This account is disabled.';
        case 'too-many-requests':
        case 'quota-exceeded':
          return 'Too many requests. Please wait before trying again.';
        case 'operation-not-allowed':
        case 'configuration-not-found':
          return 'Enable Email/Password in Firebase Authentication first.';
        case 'network-request-failed':
          return 'Check your internet connection and try again.';
        case 'admin-restricted-operation':
          return 'Account creation is disabled in Firebase. Check Email/Password and the user signup settings.';
        case 'invalid-api-key':
        case 'app-not-authorized':
          return 'Firebase rejected this app configuration. Check the Web API key and its restrictions.';
        case 'unauthorized-domain':
          return 'Add this website domain to Firebase Authentication Authorized domains.';
        case 'web-storage-unsupported':
          return 'Your browser is blocking account storage. Allow site storage or try another browser.';
      }
      // Share only the diagnostic code, never raw server messages, credentials,
      // or email addresses. This lets the project owner identify setup failures.
      return 'Firebase could not finish (auth/${error.code}). Please share this code so the setup can be checked.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Your email is verified, but the profile is blocked. Publish the project Firestore rules, then try again.';
        case 'unavailable':
          return 'The account database is unavailable. Check your connection and retry.';
        case 'not-found':
          return 'Create the default Firestore database in Firebase, then try again.';
      }
      return 'Firebase could not finish (${error.plugin}/${error.code}). Please share this code so the setup can be checked.';
    }
    return 'Verification could not finish (${error.runtimeType}). Try again and share this error label if it continues.';
  }
}
