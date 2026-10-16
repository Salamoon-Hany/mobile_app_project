// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String> enableAlerts() async {
  if (!html.Notification.supported) {
    return 'Alerts are unavailable on this device.';
  }
  try {
    final p = await html.Notification.requestPermission();
    return p == 'granted'
        ? 'Alerts enabled while SANAD is open.'
        : 'Notification permission was not granted.';
  } catch (_) {
    return 'Alerts are unavailable on this device.';
  }
}

void showAlert(String title, String body) {
  if (html.Notification.supported &&
      html.Notification.permission == 'granted') {
    try {
      html.Notification(title, body: body, tag: 'sanad-update');
    } catch (_) {}
  }
}
