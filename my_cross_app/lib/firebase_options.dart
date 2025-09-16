// lib/firebase_options.dart
//
// Firebase 프로젝트 수동 연결용 설정
// 각 플랫폼(Android / iOS / Web) 별 FirebaseOptions 정의
// 콘솔에서 발급받은 키/ID/App ID 값으로 교체해야 정상 동작함

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ─────────────────────────────
  // Web
  // Firebase Console → Web 앱 → SDK 설정에 있는 값으로 교체
  // ─────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyA94BcM41qeRgQfV9pTxbiewSew4SiP18",
    authDomain: "heritageservices-23a6c.firebaseapp.com",
    projectId: "heritageservices-23a6c",
    storageBucket: "heritageservices-23a6c.appspot.com",
    messagingSenderId: "661570902154",
    appId: "1:661570902154:web:75a9559ae8bb68bada3573",
    measurementId: "G-0TTN855NBQ",
  );

  // ─────────────────────────────
  // Android
  // Firebase Console → Android 앱 → google-services.json 내부 값
  // ─────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyA94BcM41qeRgQfV9pTxbiewSew4SiP18",
    appId: "1:661570902154:android:bd3530926a8b42ada3573",
    messagingSenderId: "661570902154",
    projectId: "heritageservices-23a6c",
    storageBucket: "heritageservices-23a6c.appspot.com",
  );

  // ─────────────────────────────
  // iOS
  // Firebase Console → iOS 앱 → GoogleService-Info.plist 내부 값
  // ─────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyA94BcM41qeRgQfV9pTxbiewSew4SiP18",
    appId: "1:661570902154:ios:e1360ab0906e5f3eda3573",
    messagingSenderId: "661570902154",
    projectId: "heritageservices-23a6c",
    storageBucket: "heritageservices-23a6c.appspot.com",
    iosBundleId: "com.yourname.myCrossApp",
  );
}
