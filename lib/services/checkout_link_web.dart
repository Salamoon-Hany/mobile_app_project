// ignore: deprecated_member_use
import 'dart:html' as html;

bool openCheckoutLink(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  html.window.open(url, '_blank', 'noopener,noreferrer');
  return true;
}
