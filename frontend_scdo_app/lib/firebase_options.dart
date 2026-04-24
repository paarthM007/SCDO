// lib/firebase_options.dart
// ─────────────────────────────────────────────────────────────
// PLACEHOLDER: Replace these values with your actual Firebase
// project config from the Firebase Console.
//
// To generate this file automatically, run:
//   flutterfire configure
// ─────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── WEB ────────────────────────────────────────────────────

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB05_lmT9_WXhy55hZe8u4OeHq1PymQqtc',
    appId: '1:415414693981:web:ca3e258ea700133a881db4',
    messagingSenderId: '415414693981',
    projectId: 'scdodeployment-32cba',
    authDomain: 'scdodeployment-32cba.firebaseapp.com',
    storageBucket: 'scdodeployment-32cba.firebasestorage.app',
    measurementId: 'G-7DZZZSZW98',
  );

  // ── ANDROID ────────────────────────────────────────────────

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB05_lmT9_WXhy55hZe8u4OeHq1PymQqtc',
    appId: '1:415414693981:android:41245f8560c8ec55881db4',
    messagingSenderId: '415414693981',
    projectId: 'scdodeployment-32cba',
    storageBucket: 'scdodeployment-32cba.firebasestorage.app',
  );
}