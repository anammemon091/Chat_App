import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web; // Point to web config
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android; // Point to your android config
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS options have not been configured.');
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  // Your Web configuration (renamed from _placeholder)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyAd5EkPJFy7QCWfRLHf3J3K9WF_py3F6Y8",
    authDomain: "chat-app-31378.firebaseapp.com",
    projectId: "chat-app-31378",
    storageBucket: "chat-app-31378.firebasestorage.app",
    messagingSenderId: "791453142226",
    appId: "1:791453142226:web:9d1632ac33dc25cc9f310b",
    measurementId: "G-SVRFJ0HPLD",
  );

  // Your Android configuration (now includes ProjectId)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBTP-TG0pINTz84iQWpPcD8om2xTXwHCf0',
    appId: "1:791453142226:android:65d9ad866e9e3c469f310b",
    messagingSenderId: "791453142226",
    projectId: "chat-app-31378", // FIXED: Added this
    storageBucket: "chat-app-31378.firebasestorage.app",
  );
}