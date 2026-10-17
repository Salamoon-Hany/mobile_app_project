import 'package:flutter/foundation.dart';

import '../l10n/app_language.dart';

enum DepositMethod { visa, vodafoneCash, fawry }

extension DepositMethodLabel on DepositMethod {
  String get label => switch (this) {
    DepositMethod.visa => 'VISA',
    DepositMethod.vodafoneCash => 'Vodafone Cash',
    DepositMethod.fawry => 'Fawry',
  };
  String get code => switch (this) {
    DepositMethod.visa => 'CARD',
    DepositMethod.vodafoneCash => 'MWALLET',
    DepositMethod.fawry => 'PayAtFawry',
  };
}

String egp(int piasters) => AppLanguage.isArabic
    ? '${(piasters / 100).toStringAsFixed(2)} ج.م'
    : 'EGP ${(piasters / 100).toStringAsFixed(2)}';

class DepositQuote {
  DepositQuote(this.amountPiasters, {this.recordedFeePiasters}) {
    if (amountPiasters < 1000) {
      throw const FormatException('Minimum deposit is 10 pounds.');
    }
    if (amountPiasters > 100000000) {
      throw const FormatException('Maximum deposit is 1,000,000 pounds.');
    }
  }
  factory DepositQuote.parse(String input) {
    var text = input.trim();
    for (var i = 0; i < 10; i++) {
      text = text
          .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
          .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
    }
    text = text.replaceAll('٫', '.').replaceAll(',', '.');
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(text)) {
      throw const FormatException(
        'Enter a valid amount with up to 2 decimal places.',
      );
    }
    final parts = text.split('.');
    return DepositQuote(
      int.parse(parts.first) * 100 +
          int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0')),
    );
  }
  final int amountPiasters;
  final int? recordedFeePiasters;
  int get feePiasters =>
      recordedFeePiasters ?? (amountPiasters * 2 + 50) ~/ 100;
  int get totalPiasters => amountPiasters + feePiasters;
}

class DepositReceipt {
  const DepositReceipt({
    required this.id,
    required this.quote,
    required this.method,
    required this.email,
    required this.demo,
    this.emailPreviewOnly = false,
  });
  final String id;
  final DepositQuote quote;
  final DepositMethod method;
  final String email;
  final bool demo;
  final bool emailPreviewOnly;
  String get text =>
      '${tr('Deposit receipt')}\n\n'
      '${tr('Deposit confirmed')}: ${egp(quote.amountPiasters)}\n'
      '${tr('Payment method')}: ${tr(method.label)}\n'
      '${tr(quote.feePiasters == (quote.amountPiasters + 50) ~/ 100 ? 'Service fee (1%)' : 'Service fee (2%)')}: ${egp(quote.feePiasters)}\n'
      '${tr('Total to pay')}: ${egp(quote.totalPiasters)}\n'
      '${tr('Email')}: $email\n${tr('Reference')}: $id';
}

class WalletState extends ChangeNotifier {
  static final shared = WalletState();
  String? ownerUid;
  int _balance = 0;
  final Map<String, DepositReceipt> _receipts = {};
  int get balancePiasters => _balance;
  Map<String, dynamic> snapshot() => {
    'balance': _balance,
    'receipts': [
      for (final receipt in _receipts.values)
        {
          'id': receipt.id,
          'amount': receipt.quote.amountPiasters,
          'fee': receipt.quote.feePiasters,
          'method': receipt.method.name,
          'email': receipt.email,
        },
    ],
  };
  void restoreSnapshot(Map<String, dynamic> data) {
    final balance = data['balance'];
    if (balance is! int || balance < 0) {
      throw const FormatException('Invalid saved balance.');
    }
    final receipts = <String, DepositReceipt>{};
    for (final value in data['receipts'] as List? ?? []) {
      final row = Map<String, dynamic>.from(value as Map);
      final receipt = DepositReceipt(
        id: row['id'] as String,
        quote: DepositQuote(
          row['amount'] as int,
          recordedFeePiasters:
              row['fee'] as int? ?? ((row['amount'] as int) + 50) ~/ 100,
        ),
        method: DepositMethod.values.byName(row['method'] as String),
        email: row['email'] as String,
        demo: true,
        emailPreviewOnly: true,
      );
      receipts[receipt.id] = receipt;
    }
    _balance = balance;
    _receipts
      ..clear()
      ..addAll(receipts);
    notifyListeners();
  }

  void clear() {
    ownerUid = null;
    _balance = 0;
    _receipts.clear();
    notifyListeners();
  }

  void attach(String uid) {
    if (ownerUid == uid) return;
    clear();
    ownerUid = uid;
  }

  void setBalance(int value) {
    if (value < 0) throw const FormatException('Insufficient balance.');
    _balance = value;
    notifyListeners();
  }

  DepositReceipt creditDemo(String uid, DepositReceipt receipt) {
    if (ownerUid != uid || !receipt.demo) {
      throw const FormatException('Your account changed. Please log in again.');
    }
    if (_receipts.containsKey(receipt.id)) {
      final previous = _receipts[receipt.id]!;
      if (previous.quote.amountPiasters != receipt.quote.amountPiasters ||
          previous.method != receipt.method) {
        throw const FormatException('This deposit reference was already used.');
      }
      return previous;
    }
    _receipts[receipt.id] = receipt;
    _balance += receipt.quote.amountPiasters;
    notifyListeners();
    return receipt;
  }
}
