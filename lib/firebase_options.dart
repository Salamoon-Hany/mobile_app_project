import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Client configuration for the registered Salamoon Web app.
/// Register Android/iOS apps with FlutterFire before building those platforms.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'This Firebase project is configured for Web only. Run flutterfire configure '
      '--project=salamoon-services to register and configure mobile platforms.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDErM-SGwWQ76_YTj_AIiZbD8ODBdh9d0g',
    appId: '1:859176819205:web:03ac89a6396d877e3e9a6c',
    messagingSenderId: '859176819205',
    projectId: 'salamoon-services',
    authDomain: 'salamoon-services.firebaseapp.com',
    storageBucket: 'salamoon-services.firebasestorage.app',
    measurementId: 'G-4L75VEQPDY',
  );
}
