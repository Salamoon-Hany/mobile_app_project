import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'screens/dashboard.dart';


void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}
