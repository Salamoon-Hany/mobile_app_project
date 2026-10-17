import 'dart:async';
import 'dart:convert';
import 'secure_api.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/dashboard.dart';
import '../l10n/app_language.dart';
import '../models/wallet.dart';
import '../models/selected_location.dart';
import 'verification_service.dart';
import 'local_account_store.dart';
import 'browser_alerts.dart' as alerts;

class Marketplace extends ChangeNotifier {
  @visibleForTesting
  Future<Map<String, dynamic>> Function(
    String path,
    Map<String, dynamic>? body,
  )?
  testTransport;
  static final shared = Marketplace();
  static bool get enabled =>
      VerificationService.configured &&
      (kIsWeb ||
          const String.fromEnvironment('MARKETPLACE_API_URL').isNotEmpty);
  Map<String, dynamic>? account;
  Map<String, dynamic>? workerApplication;
  Map<String, dynamic>? rating;
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> quotes = [], notices = [];
  bool isAdmin = false,
      workerApplicationRequested = false,
      _noticesReady = false;
  final Set<String> _seenNotices = {};
  List<Map<String, dynamic>> withdrawals = [];
  String? error;
  Timer? _timer;
  String? _uid;
  int _generation = 0;
  bool _refreshing = false;
  int get unreadCount => notices.where((n) => n['read'] != true).length;
  bool get isWorker => account?['role'] == 'worker';
  List<Map<String, dynamic>> get assignedOrders => orders
      .where(
        (o) => o['worker_uid'] == null || o['worker_uid'] == account?['uid'],
      )
      .toList();
  static String id() =>
      '${DateTime.now().microsecondsSinceEpoch}_${UniqueKey().hashCode.abs()}';
  static String? photoData(Uint8List? bytes) {
    if (bytes == null) return null;
    final mime = bytes.length > 3 && bytes[0] == 0x89
        ? 'png'
        : bytes.length > 12 && bytes[0] == 0x52
        ? 'webp'
        : 'jpeg';
    return 'data:image/$mime;base64,${base64Encode(bytes)}';
  }

  static Uint8List? photoBytes(String? data) =>
      data == null ? null : base64Decode(data.split(',').last);
  static Future<void> rememberRole(
    String uid,
    String role, {
    String? name,
    String? phone,
    String? nationalId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('sanad.signup.role.$uid', role)) {
      throw const FormatException('Could not save your account. Please retry.');
    }
    if (!enabled) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) {
      throw const FormatException('Sign in again to continue.');
    }
    final token = await user.getIdToken();
    final base = const String.fromEnvironment('MARKETPLACE_API_URL');
    final response = await http
        .post(
          secureEndpoint(
            Uri.parse(
              '${base.isEmpty ? Uri.base.origin : base}/api/marketplace/signup-role',
            ),
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'role': role,
            'name': name ?? user.displayName,
            if (phone != null) 'phone': phone,
            if (nationalId != null) 'nationalId': nationalId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const FormatException('Could not save your account. Please retry.');
    }
  }

  Future<void> _queue = Future.value();
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) {
    if (testTransport != null) return testTransport!(path, body);
    final generation = _generation;
    final future = _queue.then((_) {
      if (generation != _generation) {
        throw const FormatException(
          'Your account changed. Please log in again.',
        );
      }
      return _request(path, body: body);
    });
    _queue = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified || user.uid != _uid) {
      throw const FormatException('Sign in again to continue.');
    }
    final uid = user.uid,
        generation = _generation,
        token = await user.getIdToken();
    final base = const String.fromEnvironment('MARKETPLACE_API_URL');
    final uri = Uri.parse(
      '${base.isEmpty ? Uri.base.origin : base}/api/marketplace/$path',
    );
    secureEndpoint(uri);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response =
        await (body == null
                ? http.get(uri, headers: headers)
                : http.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 20));
    if (_uid != uid ||
        _generation != generation ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      throw const FormatException('Your account changed. Please log in again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = decodeApiObject(response.body)['error'];
      throw FormatException(switch (code) {
        'RATE_LIMIT' => 'Too many requests. Please wait before trying again.',
        'INSUFFICIENT_BALANCE' => 'Insufficient balance. Add funds first.',
        'WORKER_UNAVAILABLE' =>
          'This worker is unavailable for these services.',
        'ORDER_CHANGED' => 'The order has changed. Refresh and try again.',
        'APPLICATION_LOCKED' => 'This application can no longer be edited.',
        'QUOTE_CHANGED' => 'The quote changed. Refresh and review the price.',
        'REVIEW_LOCKED' => 'Your review has already been submitted.',
        'INVALID_APPOINTMENT' => 'Choose a time within the next 90 days.',
        'FORBIDDEN' => 'You do not have permission for this action.',
        'INVALID_AMOUNT' => 'Enter a valid amount.',
        'INVALID_COMPLAINT' => 'Choose a reason and describe the problem.',
        'INVALID_RATING' => 'Choose a rating from 1 to 5 stars.',
        'ACCOUNT_DELETING' =>
          'Account deletion is pending. Retry deleting your account.',
        'INVALID_NATIONAL_ID' => 'Enter a valid 14-digit Egyptian national ID.',
        'INVALID_DESTINATION' =>
          'Enter a valid InstaPay address ending in @instapay.',
        'INVALID_PHONE' => 'Enter a valid phone number with country code.',
        'INVALID_EXPERIENCE' => 'Enter years of experience from 0 to 60.',
        'INVALID_COUNTRIES' => 'Choose at least one country.',
        'INVALID_SERVICES' => 'Choose at least one work type.',
        'INVALID_PHOTO' => 'Choose a smaller photo (up to 500 KB).',
        _ => 'Could not sync your account. Check your connection and retry.',
      });
    }
    return decodeApiObject(response.body);
  }

  Future<bool> identify(User user) async {
    stop();
    _uid = user.uid;
    final data = await request('session');
    isAdmin = data['isAdmin'] == true && data['role'] == 'admin';
    notifyListeners();
    return isAdmin;
  }

  Future<void> attach(User user) async {
    if (_uid == user.uid && account != null) return;
    stop();
    _uid = user.uid;
    final prefs = await SharedPreferences.getInstance();
    final legacy = [
      for (final o in OrdersManager.getOrders())
        {
          'id': o.id,
          'service': o.service,
          'description': o.description,
          'status': o.status,
          'icon': o.icon,
          'createdAt': o.createdAt.toIso8601String(),
          'statusChangedAt': o.statusChangedAt.toIso8601String(),
          'location': o.location == null
              ? null
              : {
                  'latitude': o.location!.latitude,
                  'longitude': o.location!.longitude,
                  'label': o.location!.label,
                  'fromGps': o.location!.fromGps,
                },
        },
    ];
    final localPhoto = photoData(AppState.getUserProfileImageBytes());
    apply(
      await request(
        'bootstrap',
        body: {
          'name': AppState.getUserName(),
          'gender': AppState.getUserGender(),
          'role':
              prefs.getString('sanad.signup.role.${user.uid}') ?? 'customer',
          'legacyBalance':
              prefs.getBool('sanad.cloud.migrated.${user.uid}') == true
              ? 0
              : WalletState.shared.balancePiasters,
          'hasLegacy':
              LocalAccountStore.hadSavedRecords(user.uid) &&
              prefs.getBool('sanad.cloud.migrated.${user.uid}') != true,
          'legacyOrders': legacy,
          'legacyReceipts': WalletState.shared.snapshot()['receipts'],
          'photo': localPhoto != null && localPhoto.length < 700000
              ? localPhoto
              : null,
        },
      ),
    );
    await prefs.setBool('sanad.cloud.migrated.${user.uid}', true);
    await LocalAccountStore.markCloudBacked(user.uid);
    await prefs.remove('sanad.signup.role.${user.uid}');
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _uid = null;
    account = null;
    workerApplication = null;
    rating = null;
    orders = [];
    quotes = [];
    notices = [];
    isAdmin = false;
    workerApplicationRequested = false;
    _noticesReady = false;
    _seenNotices.clear();
    withdrawals = [];
    error = null;
    _generation++;
    _refreshing = false;
  }

  Future<void> refresh() async {
    if (_refreshing || _uid == null) return;
    _refreshing = true;
    try {
      apply(await request('snapshot'));
    } catch (e) {
      if (_uid != null) {
        error = e is FormatException
            ? e.message
            : 'Could not sync your account. Check your connection and retry.';
        notifyListeners();
      }
    } finally {
      _refreshing = false;
    }
  }

  void apply(Map<String, dynamic> data) {
    account = Map<String, dynamic>.from(data['account'] as Map);
    isAdmin = data['isAdmin'] == true;
    workerApplicationRequested = data['workerApplicationRequested'] == true;
    quotes = (data['quotes'] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    notices = (data['notices'] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    for (final n in notices) {
      if (_noticesReady &&
          !_seenNotices.contains(n['id']) &&
          n['read'] != true) {
        alerts.showAlert(tr('SANAD update'), tr(n['body'] as String));
      }
      _seenNotices.add(n['id'] as String);
    }
    _noticesReady = true;
    workerApplication = data['workerApplication'] == null
        ? null
        : Map<String, dynamic>.from(data['workerApplication'] as Map);
    rating = data['rating'] == null
        ? null
        : Map<String, dynamic>.from(data['rating'] as Map);
    withdrawals = (data['withdrawals'] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    orders = (data['orders'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    error = null;
    WalletState.shared.restoreSnapshot({
      'balance': account!['balance'],
      'receipts': [
        for (final r in data['deposits'] as List)
          {
            ...Map<String, dynamic>.from(r as Map),
            'email': AppState.getUserEmail(),
          },
      ],
    });
    final serverPhoto = account!['photo'] as String?;
    AppState.setUserProfileImageBytes(photoBytes(serverPhoto));
    AppState.setPhoneNumber(
      (account!['contact_phone'] as String? ?? '').isNotEmpty
          ? account!['contact_phone'] as String
          : account!['phone'] as String? ?? '',
    );
    AppState.setUserGender(account!['gender'] as String? ?? '');
    AppState.setUserName(account!['name'] as String);
    final display = <OrderModel>[];
    for (final o in orders) {
      final loc = Map<String, dynamic>.from(o['location'] as Map);
      display.add(
        OrderModel(
          id: o['id'] as String,
          service: (o['services'] as List)
              .map((id) => jobCatalog.firstWhere((j) => j.id == id).name)
              .join(', '),
          description: o['details'] as String,
          status: o['status'] as String,
          icon: '🛠️',
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            o['created_at'] as int,
          ),
          statusChangedAt: DateTime.fromMillisecondsSinceEpoch(
            o['updated_at'] as int,
          ),
          workerName: o['worker_name'] as String,
          amount: o['amount'] as int,
          cloud: true,
          photo: o['photo'] as String?,
          hasPhoto: o['has_photo'] == 1,
          location: SelectedLocation(
            latitude: (loc['latitude'] as num).toDouble(),
            longitude: (loc['longitude'] as num).toDouble(),
            label: loc['label'] as String,
            fromGps: loc['fromGps'] == true,
          ),
        ),
      );
    }
    for (final v in account!['legacy_orders'] as List) {
      try {
        final o = Map<String, dynamic>.from(v as Map);
        final loc = o['location'] as Map?;
        display.add(
          OrderModel(
            id: o['id'] as String,
            service: o['service'] as String,
            description: o['description'] as String,
            status: 'archived',
            icon: o['icon'] as String,
            createdAt: DateTime.parse(o['createdAt'] as String),
            statusChangedAt: DateTime.parse(o['statusChangedAt'] as String),
            location: loc == null
                ? null
                : SelectedLocation(
                    latitude: (loc['latitude'] as num).toDouble(),
                    longitude: (loc['longitude'] as num).toDouble(),
                    label: loc['label'] as String,
                  ),
          ),
        );
      } catch (_) {
        /* Preserve the raw legacy record on the server. */
      }
    }
    OrdersManager.restore(display);
    notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    List<String>? skills,
    Uint8List? photo,
    bool replacePhoto = false,
    String? phone,
    String? gender,
    String? nationalId,
    bool? available,
  }) async => apply(
    await request(
      'profile',
      body: {
        'name': name,
        if (skills != null) 'skills': skills,
        if (available != null) 'available': available,
        if (photo != null || replacePhoto) 'photo': photoData(photo),
        if (phone != null) 'phone': phone,
        if (gender != null) 'gender': gender,
        if (nationalId != null) 'nationalId': nationalId,
      },
    ),
  );
  Future<List<Map<String, dynamic>>> workers(List<String> services) async =>
      ((await request('workers?services=${services.join(',')}'))['workers']
              as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
  Future<void> submitWorkerApplication(
    Map<String, dynamic> application,
  ) async => apply(await request('worker-application', body: application));
  Future<void> rateApp(int stars, {String comment = ''}) async => apply(
    await request('rating', body: {'stars': stars, 'comment': comment}),
  );
  Future<void> withdraw(Map<String, dynamic> input) async =>
      apply(await request('withdrawals', body: input));
  Future<void> cancelWithdrawal(String id) async =>
      apply(await request('withdrawals/$id/cancel', body: {}));
  Future<Uint8List?> orderPhoto(String id) async =>
      photoBytes((await request('orders/$id/photo'))['photo'] as String?);
  Future<void> decide(String id, String action) async =>
      apply(await request('orders/$id/decision', body: {'action': action}));
  Future<void> createOrder(String requestId) async {
    final location = BookingState.selectedLocation!;
    apply(
      await request(
        'orders',
        body: {
          'requestId': requestId,
          'workerUid': BookingState.selectedWorker!.id,
          'services': BookingState.selectedJobs.map((j) => j.id).toList(),
          'details': BookingState.locationDetails ?? '',
          'photo': photoData(BookingState.photoBytes),
          'location': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'label': location.label,
            'fromGps': location.fromGps,
          },
        },
      ),
    );
  }

  Future<void> createQuote(String requestId) async {
    final location = BookingState.selectedLocation!;
    apply(
      await request(
        'quotes',
        body: {
          'requestId': requestId,
          'workerUid': BookingState.selectedWorker!.id,
          'services': BookingState.selectedJobs.map((j) => j.id).toList(),
          'details': BookingState.locationDetails ?? '',
          'photo': photoData(BookingState.photoBytes),
          'location': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'label': location.label,
            'fromGps': location.fromGps,
          },
        },
      ),
    );
  }

  Future<DepositReceipt> deposit(
    DepositQuote quote,
    DepositMethod method,
    String id,
  ) async {
    apply(
      await request(
        'deposit',
        body: {
          'requestId': id,
          'amount': quote.amountPiasters,
          'method': method.name,
        },
      ),
    );
    return DepositReceipt(
      id: id,
      quote: quote,
      method: method,
      email: AppState.getUserEmail(),
      demo: true,
      emailPreviewOnly: true,
    );
  }
}
