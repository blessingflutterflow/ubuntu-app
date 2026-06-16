// Generated / manually configured for project: ubuntu-8d0ad
// Run `flutterfire configure` to regenerate with web + iOS app IDs.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS:     return ios;
      default:                     return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyCSEq7ndlYzHSI5K-vWHb8aFwir-xBUgYU',
    appId:             '1:1017117739615:android:cbadaaed8ca84ea57769ea',
    messagingSenderId: '1017117739615',
    projectId:         'ubuntu-8d0ad',
    storageBucket:     'ubuntu-8d0ad.firebasestorage.app',
    databaseURL:       'https://ubuntu-8d0ad-default-rtdb.firebaseio.com',
  );

  // TODO: Run `flutterfire configure --project=ubuntu-8d0ad` to get the real web + iOS app IDs.
  // For now these use the Android values so the app compiles.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyCSEq7ndlYzHSI5K-vWHb8aFwir-xBUgYU',
    appId:             '1:1017117739615:web:REPLACE_WITH_WEB_APP_ID',
    messagingSenderId: '1017117739615',
    projectId:         'ubuntu-8d0ad',
    storageBucket:     'ubuntu-8d0ad.firebasestorage.app',
    authDomain:        'ubuntu-8d0ad.firebaseapp.com',
    databaseURL:       'https://ubuntu-8d0ad-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyCSEq7ndlYzHSI5K-vWHb8aFwir-xBUgYU',
    appId:             '1:1017117739615:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '1017117739615',
    projectId:         'ubuntu-8d0ad',
    storageBucket:     'ubuntu-8d0ad.firebasestorage.app',
    databaseURL:       'https://ubuntu-8d0ad-default-rtdb.firebaseio.com',
    iosBundleId:       'com.ubuntuoasis.ubuntu',
  );
}
