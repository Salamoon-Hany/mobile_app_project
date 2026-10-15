import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app_project/services/secure_api.dart';
import 'package:mobile_app_project/services/phone_login_service.dart';
import 'package:mobile_app_project/services/verification_service.dart';
import 'package:mobile_app_project/models/selected_location.dart';

void main() {
  test('API endpoints reject insecure and credential-bearing URLs', () {
    for (final value in [
      'http://example.com/api',
      'https://user:secret@example.com/api',
      'https://example.com/api#token',
    ]) {
      expect(() => secureEndpoint(Uri.parse(value)), throwsFormatException);
    }
    expect(
      secureEndpoint(Uri.parse('https://example.com/api')).scheme,
      'https',
    );
  });
  test(
    'service output rejects non-objects, large bodies and non-finite numbers',
    () {
      for (final value in ['[]', 'null', '{"amount":1e400}']) {
        expect(() => decodeApiObject(value), throwsFormatException);
      }
      expect(
        () => decodeApiObject('{"text":"long"}', maximum: 5),
        throwsFormatException,
      );
      expect(decodeApiObject('{"balance":100}')['balance'], 100);
    },
  );
  test('checkout URLs allow only exact provider hosts over HTTPS', () {
    expect(isTrustedCheckout('https://atfawry.com/pay/123'), isTrue);
    for (final value in [
      'https://evil.test',
      'http://atfawry.com',
      'https://atfawry.com.evil.test',
      'https://secret@atfawry.com',
      'https://atfawry.com:8443/pay',
    ]) {
      expect(isTrustedCheckout(value), isFalse);
    }
  });
  test(
    'email preflight uses same-origin server and never accepts a different identity',
    () async {
      final service = PhoneLoginService(
        base: Uri.parse('https://sanad.test'),
        client: MockClient((r) async {
          expect(r.url.path, '/api/auth/login');
          expect(jsonDecode(r.body)['identifier'], 'person@example.com');
          return http.Response(
            '{"uid":"uid-1","email":"person@example.com"}',
            200,
          );
        }),
      );
      expect(
        (await service.checkEmail('person@example.com', 'test-only')).uid,
        'uid-1',
      );
      service.dispose();
      final forged = PhoneLoginService(
        base: Uri.parse('https://sanad.test'),
        client: MockClient(
          (_) async =>
              http.Response('{"uid":"other","email":"other@example.com"}', 200),
        ),
      );
      await expectLater(
        forged.checkEmail('person@example.com', 'test-only'),
        throwsFormatException,
      );
      forged.dispose();
    },
  );
  test('server throttling shows a wait message with no raw response', () async {
    final service = PhoneLoginService(
      base: Uri.parse('https://sanad.test'),
      client: MockClient(
        (_) async => http.Response('private SQL details', 429),
      ),
    );
    try {
      await service.checkEmail('person@example.com', 'test-only');
      fail('should reject');
    } catch (error) {
      expect(
        VerificationService.message(error),
        'Too many requests. Please wait before trying again.',
      );
    } finally {
      service.dispose();
    }
    expect(
      VerificationService.message(const FormatException('password=secret SQL')),
      isNot(contains('secret')),
    );
  });
  test('external geocoder coordinates are finite and in range', () {
    for (final point in [
      [181, 30],
      [31, 91],
      [double.infinity, 30],
    ]) {
      expect(
        () => SelectedLocation.fromPhoton({
          'geometry': {'coordinates': point},
          'properties': {},
        }),
        throwsFormatException,
      );
    }
  });
}
