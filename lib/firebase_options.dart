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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyBfABh3toKwifCej05Fr6EHRRGQt29dRgI',
    appId: '1:526760006745:web:f66ef43c6931e2db68cd48',
    messagingSenderId: '526760006745',
    projectId: 'ica16-cloud-quiz-ceab96',
    authDomain: 'ica16-cloud-quiz-ceab96.firebaseapp.com',
    storageBucket: 'ica16-cloud-quiz-ceab96.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDxTpO8e1Uk9YLnu-iIduXQJzJQtgSm30I',
    appId: '1:526760006745:android:868981c2e716855f68cd48',
    messagingSenderId: '526760006745',
    projectId: 'ica16-cloud-quiz-ceab96',
    storageBucket: 'ica16-cloud-quiz-ceab96.firebasestorage.app',
  );
}
