import 'dart:convert';
import 'package:flutter/foundation.dart';

Uri secureEndpoint(Uri uri) {
  final localDebug =
      kDebugMode && ['localhost', '127.0.0.1', '[::1]'].contains(uri.host);
  if ((!localDebug && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException('A secure connection is required.');
  }
  return uri;
}

Map<String, dynamic> decodeApiObject(String body, {int maximum = 4000000}) {
  if (body.length > maximum)
    throw const FormatException(
      'The service response is invalid. Please retry.',
    );
  final data = jsonDecode(body);
  if (data is! Map<String, dynamic>)
    throw const FormatException(
      'The service response is invalid. Please retry.',
    );
  int nodes = 0;
  void validate(dynamic value, int depth) {
    if (++nodes > 80000 || depth > 16 || (value is num && !value.isFinite)) {
      throw const FormatException(
        'The service response is invalid. Please retry.',
      );
    }
    if (value is List) {
      if (value.length > 3000)
        throw const FormatException(
          'The service response is invalid. Please retry.',
        );
      for (final item in value) {
        validate(item, depth + 1);
      }
    } else if (value is Map) {
      for (final item in value.values) {
        validate(item, depth + 1);
      }
    }
  }

  validate(data, 0);
  return data;
}

bool isTrustedCheckout(String input) {
  final uri = Uri.tryParse(input);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      [
        'atfawry.com',
        'www.atfawry.com',
        'atfawry.fawrystaging.com',
      ].contains(uri.host);
}
