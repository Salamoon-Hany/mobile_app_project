import 'dart:convert';
import 'secure_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/phone_number.dart';

class PhoneLoginAccount {
  const PhoneLoginAccount(this.uid, this.email);
  final String uid;
  final String email;
}

class PhoneLoginService {
  static final Set<String> _registered = {};
  static final Set<String> _inFlight = {};
  PhoneLoginService({FirebaseAuth? auth, http.Client? client, Uri? base})
    : _authOverride = auth,
      _client = client ?? http.Client(),
      _base = base ?? _defaultBase;
  final FirebaseAuth? _authOverride;
  final http.Client _client;
  final Uri _base;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  static Uri get _defaultBase => kIsWeb
      ? Uri.parse(Uri.base.origin)
      : Uri.parse(
          const String.fromEnvironment(
            'PHONE_LOGIN_BASE_URL',
            defaultValue:
                'https://eslam-mobile-service-app.eslam-hanyram11.chatgpt.site',
          ),
        );
  void dispose() => _client.close();

  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    secureEndpoint(_base);
    final response = await _client
        .post(
          _base.resolve(
            action == 'email-login'
                ? '/api/auth/login'
                : '/api/auth/phone/$action',
          ),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 429) {
      throw const FormatException(
        'Too many requests. Please wait before trying again.',
      );
    }
    if (response.statusCode == 400 || response.statusCode == 401) {
      throw const FormatException(
        'Email or password is incorrect. Sign up if you need an account.',
      );
    }
    if (response.statusCode != 200) {
      throw const FormatException(
        'Mobile login is temporarily unavailable. Sign in with your email or try again.',
      );
    }
    return decodeApiObject(response.body, maximum: 8192);
  }

  Future<PhoneLoginAccount> checkEmail(String email, String password) async {
    final data = await _post('email-login', {
      'identifier': email,
      'password': password,
    });
    if (data['uid'] is! String ||
        (data['uid'] as String).isEmpty ||
        (data['uid'] as String).length > 128 ||
        data['email'] is! String ||
        (data['email'] as String).toLowerCase() != email.toLowerCase()) {
      throw const FormatException(
        'Sign in is temporarily unavailable. Please retry later.',
      );
    }
    return PhoneLoginAccount(data['uid'] as String, data['email'] as String);
  }

  Future<PhoneLoginAccount> resolve(String phone, String password) async {
    final data = await _post('login', {
      'phone': normalizePhone(phone),
      'password': password,
    });
    if (data['uid'] is! String || data['email'] is! String) {
      throw const FormatException(
        'Mobile login is temporarily unavailable. Sign in with your email or try again.',
      );
    }
    return PhoneLoginAccount(data['uid'] as String, data['email'] as String);
  }

  Future<void> registerCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null ||
        !user.emailVerified ||
        user.isAnonymous ||
        (user.phoneNumber ?? '').isEmpty) {
      return;
    }
    final token = await user.getIdToken();
    if (token == null) return;
    await _post('register', {}, token: token);
  }

  static Future<void> syncVerifiedPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || (user.phoneNumber ?? '').isEmpty) return;
    final key = '${user.uid}:${user.phoneNumber}:${user.email}';
    if (_registered.contains(key) || !_inFlight.add(key)) return;
    final service = PhoneLoginService();
    try {
      await service.registerCurrentUser();
      _registered.add(key);
    } finally {
      _inFlight.remove(key);
      service.dispose();
    }
  }
}
