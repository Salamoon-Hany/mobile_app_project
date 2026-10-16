import 'secure_api.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/wallet.dart';
import 'local_account_store.dart';
import 'marketplace_service.dart';

class DepositSession {
  const DepositSession({
    required this.id,
    this.checkoutUrl,
    this.receipt,
    this.emailStatus = 'not-sent',
    this.status = 'PENDING',
  });
  final String id;
  final String? checkoutUrl;
  final DepositReceipt? receipt;
  final String emailStatus;
  final String status;
}

class WalletService {
  WalletService({
    FirebaseAuth? auth,
    WalletState? state,
    String? backendUrl,
    http.Client? client,
  }) : _authOverride = auth,
       state = state ?? WalletState.shared,
       _base =
           backendUrl ?? const String.fromEnvironment('WALLET_API_BASE_URL'),
       _client = client ?? http.Client();
  final FirebaseAuth? _authOverride;
  final WalletState state;
  final String _base;
  final http.Client _client;
  static bool get backendConfigured =>
      const String.fromEnvironment('WALLET_API_BASE_URL').isNotEmpty;
  bool get isDemo => _base.isEmpty;
  String _mode = 'unknown';
  String get mode => isDemo ? 'demo' : _mode;
  void dispose() => _client.close();
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  User _owner() {
    final user = _auth.currentUser;
    if (user == null ||
        user.isAnonymous ||
        !user.emailVerified ||
        (user.email ?? '').isEmpty ||
        state.ownerUid != user.uid) {
      throw const FormatException(
        'Sign in with your verified email to add funds.',
      );
    }
    return user;
  }

  void _sameUser(User owner) {
    if (_auth.currentUser?.uid != owner.uid || state.ownerUid != owner.uid) {
      throw const FormatException('Your account changed. Please log in again.');
    }
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final user = _owner();
    final token = await user.getIdToken();
    _sameUser(user);
    final uri = Uri.parse('${_base.replaceAll(RegExp(r'/+$'), '')}/$path');
    secureEndpoint(uri);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response =
        await (body == null
                ? _client.get(uri, headers: headers)
                : _client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 25));
    _sameUser(user);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const FormatException(
          'Please log in again with a verified email.',
        );
      }
      if (response.statusCode == 503) {
        throw const FormatException(
          'Payments are not configured yet. Your balance has not changed.',
        );
      }
      throw const FormatException(
        'The payment could not complete. Your balance has not changed. Retry checking its status.',
      );
    }
    final data = decodeApiObject(response.body);
    if (data['mode'] is String) _mode = data['mode'] as String;
    return data;
  }

  Future<void> refresh() async {
    if (isDemo) return;
    final data = await _request('balance');
    state.setBalance(data['balancePiasters'] as int);
  }

  Future<DepositSession> begin(
    DepositQuote quote,
    DepositMethod method,
    String requestId,
  ) async {
    final user = _owner();
    if (isDemo &&
        Marketplace.enabled &&
        Marketplace.shared.account != null &&
        identical(state, WalletState.shared)) {
      final receipt = await Marketplace.shared.deposit(
        quote,
        method,
        requestId,
      );
      return DepositSession(id: requestId, receipt: receipt);
    }
    if (isDemo) {
      final receipt = state.creditDemo(
        user.uid,
        DepositReceipt(
          id: requestId,
          quote: quote,
          method: method,
          email: user.email!,
          demo: true,
          emailPreviewOnly: true,
        ),
      );
      if (identical(state, WalletState.shared)) await LocalAccountStore.flush();
      return DepositSession(id: requestId, receipt: receipt);
    }
    final data = await _request(
      'deposit',
      body: {
        'amountPiasters': quote.amountPiasters,
        'method': method.code,
        'requestId': requestId,
      },
    );
    return DepositSession(
      id: data['id'] as String,
      checkoutUrl: data['checkoutUrl'] as String?,
      status: data['status'] as String? ?? 'PENDING',
    );
  }

  Future<DepositSession?> check(
    DepositSession session,
    DepositQuote quote,
    DepositMethod method,
  ) async {
    final user = _owner();
    final data = await _request('deposit/${session.id}');
    if (data['status'] == 'FAILED' ||
        data['status'] == 'EXPIRED' ||
        data['status'] == 'CANCELED') {
      throw const FormatException(
        'Payment was not completed. Your balance has not changed.',
      );
    }
    if (data['status'] != 'PAID') {
      return DepositSession(
        id: session.id,
        checkoutUrl: data['checkoutUrl'] as String? ?? session.checkoutUrl,
        status: data['status'] as String? ?? 'PENDING',
      );
    }
    state.setBalance(data['balancePiasters'] as int);
    return DepositSession(
      id: session.id,
      emailStatus: data['emailStatus'] as String? ?? 'queued',
      status: 'PAID',
      receipt: DepositReceipt(
        id: session.id,
        quote: quote,
        method: method,
        email: user.email!,
        demo: data['mode'] != 'live',
      ),
    );
  }
}
