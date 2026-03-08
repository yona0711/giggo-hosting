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
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDtynkXVBa7RjCWUN6QTFXDmepfyWN6Is8',
    appId: '1:252429020972:web:9dc0373c8928e73d290689',
    messagingSenderId: '252429020972',
    projectId: 'giggo-8a302',
    authDomain: 'giggo-8a302.firebaseapp.com',
    storageBucket: 'giggo-8a302.firebasestorage.app',
    measurementId: 'G-RCQX6C722W',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCF1AhlTP7BB8ngaR7P93diyQrITL1PiyQ',
    appId: '1:252429020972:android:2811778ed0452f19290689',
    messagingSenderId: '252429020972',
    projectId: 'giggo-8a302',
    storageBucket: 'giggo-8a302.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDySmO3YUTuKEYSz1a1PhnktiQSGyKmAVk',
    appId: '1:252429020972:ios:9b3d4f75aeb2899c290689',
    messagingSenderId: '252429020972',
    projectId: 'giggo-8a302',
    storageBucket: 'giggo-8a302.firebasestorage.app',
    iosBundleId: 'com.example.giggo',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDySmO3YUTuKEYSz1a1PhnktiQSGyKmAVk',
    appId: '1:252429020972:ios:9b3d4f75aeb2899c290689',
    messagingSenderId: '252429020972',
    projectId: 'giggo-8a302',
    storageBucket: 'giggo-8a302.firebasestorage.app',
    iosBundleId: 'com.example.giggo',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDtynkXVBa7RjCWUN6QTFXDmepfyWN6Is8',
    appId: '1:252429020972:web:bcdfb302943a4085290689',
    messagingSenderId: '252429020972',
    projectId: 'giggo-8a302',
    authDomain: 'giggo-8a302.firebaseapp.com',
    storageBucket: 'giggo-8a302.firebasestorage.app',
    measurementId: 'G-JV8LTBJNL3',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_LINUX_API_KEY',
    appId: 'REPLACE_WITH_LINUX_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'giggo-8a302',
    storageBucket: 'giggo-8a302.appspot.com',
  );
}