import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../screens/dashboard.dart';
import '../models/wallet.dart';
import '../models/booking.dart';
import '../models/selected_location.dart';
import 'account_service.dart';

/// Local project data, isolated by verified account UID. This is deliberately
/// separate from the server-controlled real-payment wallet.
class LocalAccountStore {
  static SharedPreferences? _preferences;
  static Future<void> _pending = Future.value();
  static bool _restoring = false;
  static bool _started = false;
  static final Set<String> _restoredRecords = {};
  static bool hadSavedRecords(String uid) => _restoredRecords.contains(uid);
  static Object? _lastError;
  static Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    if (_started) return;
    _started = true;
    WalletState.shared.addListener(save);
    OrdersManager.notifier.addListener(save);
  }

  static String _key(String uid) => 'sanad.account.v1.$uid';
  static void restore(String uid) {
    if (_preferences == null || WalletServiceBackend.enabled) return;
    final raw = _preferences!.getString(_key(uid));
    if (raw == null) return;
    _restoredRecords.add(uid);
    _restoring = true;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['uid'] != uid || data['version'] != 1) return;
      final wallet = Map<String, dynamic>.from(data['wallet'] as Map);
      // An unfinished draft is abandoned on restart; refund its reservation.
      wallet['balance'] =
          (wallet['balance'] as int) + (data['held'] as int? ?? 0);
      final restored = <OrderModel>[];
      for (final item in (data['orders'] as List? ?? [])) {
        final row = Map<String, dynamic>.from(item as Map);
        final location = row['location'] as Map?;
        restored.add(
          OrderModel(
            id: row['id'] as String,
            service: row['service'] as String,
            description: row['description'] as String,
            status: row['status'] as String,
            icon: row['icon'] as String,
            createdAt: DateTime.parse(row['createdAt'] as String),
            statusChangedAt: DateTime.parse(row['statusChangedAt'] as String),
            location: location == null
                ? null
                : SelectedLocation(
                    latitude: (location['latitude'] as num).toDouble(),
                    longitude: (location['longitude'] as num).toDouble(),
                    label: location['label'] as String,
                    fromGps: location['fromGps'] == true,
                  ),
          ),
        );
      }
      WalletState.shared.restoreSnapshot(wallet);
      OrdersManager.restore(restored);
      final photo = data['profilePhoto'] as String?;
      AppState.setUserProfileImageBytes(
        photo == null ? null : base64Decode(photo),
      );
      _lastError = null;
    } catch (error) {
      _lastError = error;
      return;
    } finally {
      _restoring = false;
    }
    save();
  }

  static void save() {
    final uid = AccountService.activeUid;
    if (_restoring ||
        _preferences == null ||
        uid == null ||
        WalletState.shared.ownerUid != uid ||
        WalletServiceBackend.enabled)
      return;
    final snapshot = jsonEncode({
      'version': 1,
      'uid': uid,
      'wallet': WalletState.shared.snapshot(),
      'held': BookingState.reservedPiasters,
      'profilePhoto': AppState.getUserProfileImageBytes() == null
          ? null
          : base64Encode(AppState.getUserProfileImageBytes()!),
      'orders': [
        for (final order in OrdersManager.getOrders())
          {
            'id': order.id,
            'service': order.service,
            'description': order.description,
            'status': order.status,
            'icon': order.icon,
            'createdAt': order.createdAt.toIso8601String(),
            'statusChangedAt': order.statusChangedAt.toIso8601String(),
            'location': order.location == null
                ? null
                : {
                    'latitude': order.location!.latitude,
                    'longitude': order.location!.longitude,
                    'label': order.location!.label,
                    'fromGps': order.location!.fromGps,
                  },
          },
      ],
    });
    // Capture UID and bytes now so late writes cannot overwrite another account.
    _pending = _pending.then((_) async {
      try {
        if (!await _preferences!.setString(_key(uid), snapshot))
          throw StateError('Storage rejected the write');
        _lastError = null;
      } catch (error) {
        _lastError = error;
      }
    });
  }

  static Future<void> erase(String uid) async {
    await _pending;
    _restoredRecords.remove(uid);
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    for (final key in [
      _key(uid),
      'sanad.signup.role.$uid',
      'sanad.cloud.migrated.$uid',
    ]) {
      await prefs.remove(key);
    }
  }

  static Future<void> flush() async {
    await _pending;
    if (_lastError != null)
      throw const FormatException(
        'Could not save your account data on this device. Please retry.',
      );
  }
}

class WalletServiceBackend {
  static bool get enabled =>
      const String.fromEnvironment('WALLET_API_BASE_URL').isNotEmpty;
}
