import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/profile_validation.dart';

enum AccountAction { login, signup }

bool hasVerifiedContact(User? user) =>
    user != null &&
    !user.isAnonymous &&
    user.emailVerified &&
    (user.email?.isNotEmpty ?? false);

class AccountService {
  static String? activeUid;
  static bool authenticationInProgress = false;
  static bool deletionInProgress = false;
  static DocumentReference<Map<String, dynamic>> profile(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  static Future<void> finish(AccountAction action, {String? name}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!hasVerifiedContact(user)) {
      throw StateError('Verify your email first.');
    }
    // Rules require a fresh email_verified claim, not just a client flag.
    await user!.getIdToken(true);
    final ref = profile(user.uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) return;
      // Recover an interrupted signup without creating a second Auth identity.
      // Login itself never creates a Firebase Auth account.
      final displayName = (name ?? user.displayName ?? '').trim();
      if (displayName.length < 2 || displayName.length > 80) {
        throw const FormatException('Enter your full name (2–80 characters).');
      }
      transaction.set(ref, {
        'uid': user.uid,
        'name': displayName,
        'gender': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> saveProfile({
    required String name,
    required String gender,
  }) async {
    validateProfile(name: name, gender: gender);
    final user = FirebaseAuth.instance.currentUser;
    if (!hasVerifiedContact(user) || user!.uid != activeUid) {
      throw StateError('Sign in again to save your profile.');
    }
    // Contacts are owned by Firebase Auth and can only change through verification.
    await profile(user.uid).update({
      'name': name.trim(),
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
