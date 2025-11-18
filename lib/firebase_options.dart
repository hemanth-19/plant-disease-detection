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
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCayduPvyR3cT0gz7hsJ2a38HCeRYY-E3E',
    appId: '1:256546103195:web:bfc4199457c0faea5f0b3e',
    messagingSenderId: '256546103195',
    projectId: 'plant-disease-demo-a7a8a',
    authDomain: 'plant-disease-demo-a7a8a.firebaseapp.com',
    storageBucket: 'plant-disease-demo-a7a8a.firebasestorage.app',
    measurementId: 'G-FCEGCFMZWV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCayduPvyR3cT0gz7hsJ2a38HCeRYY-E3E',
    appId: '1:256546103195:android:bfc4199457c0faea5f0b3e',
    messagingSenderId: '256546103195',
    projectId: 'plant-disease-demo-a7a8a',
    storageBucket: 'plant-disease-demo-a7a8a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCayduPvyR3cT0gz7hsJ2a38HCeRYY-E3E',
    appId: '1:256546103195:ios:bfc4199457c0faea5f0b3e',
    messagingSenderId: '256546103195',
    projectId: 'plant-disease-demo-a7a8a',
    storageBucket: 'plant-disease-demo-a7a8a.firebasestorage.app',
    iosBundleId: 'com.example.cameraFirebaseApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCayduPvyR3cT0gz7hsJ2a38HCeRYY-E3E',
    appId: '1:256546103195:ios:bfc4199457c0faea5f0b3e',
    messagingSenderId: '256546103195',
    projectId: 'plant-disease-demo-a7a8a',
    storageBucket: 'plant-disease-demo-a7a8a.firebasestorage.app',
    iosBundleId: 'com.example.cameraFirebaseApp',
  );
}