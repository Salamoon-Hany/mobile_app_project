import 'secure_api.dart';
// ignore: deprecated_member_use
import 'dart:html' as html;

bool openCheckoutLink(String url) {
  if (!isTrustedCheckout(url)) return false;
  html.window.open(url, '_blank', 'noopener,noreferrer');
  return true;
}
