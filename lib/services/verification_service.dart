import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'phone_login_service.dart';

String normalizeLoginIdentifier(String input) => normalizeEmail(input);

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
    final normalized = normalizeEmail(email);
    final service = _phoneLogin ?? PhoneLoginService();
    try {
      final checked = _injectedAuth == null || _phoneLogin != null
          ? await service.checkEmail(normalized, password)
          : null;
      final result = await _auth.signInWithEmailAndPassword(
        email: normalized,
        password: password,
      );
      await result.user?.reload();
      if (_auth.currentUser?.emailVerified == true)
        await _auth.currentUser!.getIdToken(true);
      if (checked != null && result.user?.uid != checked.uid) {
        await _auth.signOut();
        throw const FormatException(
          'Email or password is incorrect. Sign up if you need an account.',
        );
      }
    } finally {
      if (_phoneLogin == null) service.dispose();
    }
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
    if (error is FormatException) {
      const safe = {
        'Enter a valid email address.',
        'Enter a valid phone number with country code.',
        'Email or password is incorrect. Sign up if you need an account.',
        'Too many requests. Please wait before trying again.',
        'Mobile login is temporarily unavailable. Sign in with your email or try again.',
        'Sign in is temporarily unavailable. Please retry later.',
        'A secure connection is required.',
      };
      return safe.contains(error.message)
          ? error.message
          : 'Could not complete this action. Please retry later.';
    }
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
          return 'Sign in is temporarily unavailable. Please retry later.';
        case 'network-request-failed':
          return 'Check your internet connection and try again.';
        case 'admin-restricted-operation':
          return 'Account creation is temporarily unavailable. Please retry later.';
        case 'invalid-api-key':
        case 'app-not-authorized':
          return 'Sign in is temporarily unavailable. Please retry later.';
        case 'unauthorized-domain':
          return 'Sign in is temporarily unavailable. Please retry later.';
        case 'web-storage-unsupported':
          return 'Your browser is blocking account storage. Allow site storage or try another browser.';
      }
      // Share only the diagnostic code, never raw server messages, credentials,
      // or email addresses. This lets the project owner identify setup failures.
      return 'Could not complete this action. Please retry later.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Could not load your account. Please retry later.';
        case 'unavailable':
          return 'The account database is unavailable. Check your connection and retry.';
        case 'not-found':
          return 'Could not load your account. Please retry later.';
      }
      return 'Could not complete this action. Please retry later.';
    }
    return 'Could not complete this action. Please retry later.';
  }
}
