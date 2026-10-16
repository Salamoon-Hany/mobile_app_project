import 'secure_api.dart';
import 'dart:js_interop';

@JS('window.open')
external JSAny? _openCheckoutWindow(
  String url,
  String target,
  String features,
);

bool openCheckoutLink(String url) {
  if (!isTrustedCheckout(url)) return false;
  _openCheckoutWindow(url, '_blank', 'noopener,noreferrer');
  return true;
}
