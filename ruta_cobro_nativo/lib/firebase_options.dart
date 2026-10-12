import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCLVm5TEvbM9XgqP2XSKEbWdY75lNGyaaU',
    appId: '1:34627842260:android:abc304084144952be50b41',
    messagingSenderId: '34627842260',
    projectId: 'ruta-cobro-rd-prueba',
    storageBucket: 'ruta-cobro-rd-prueba.firebasestorage.app',
  );
}
