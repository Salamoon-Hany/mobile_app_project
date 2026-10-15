import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'l10n/app_language.dart';
import 'services/local_account_store.dart';
import 'screens/dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.initialize();
  await LocalAccountStore.initialize();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Fail closed: the account gate blocks services until setup is complete.
    debugPrint('Firebase is not ready. See docs/SETUP.md.');
  }
  runApp(
    DevicePreview(
      enabled: kDebugMode && const bool.fromEnvironment('DEVICE_PREVIEW'),
      builder: (context) => const MyApp(),
    ),
  );
}
