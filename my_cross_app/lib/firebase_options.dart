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
    apiKey: "AIzaSyAg4BcMA1qeRgQfV9pTxbeiwSeo4vSiP18",
    authDomain: "heritageservices-23a6c.firebaseapp.com",
    projectId: "heritageservices-23a6c",
    storageBucket: "heritageservices-23a6c.firebasestorage.app",
    messagingSenderId: "661570902154",
    appId: "1:661570902154:web:17d16562436aa476da3573",
    measurementId: "G-4RG8QBWDPG",
  );

  // ─────────────────────────────
  // Android
  // Firebase Console → Android 앱 → google-services.json 내부 값
  // ─────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyBlsoEpINCZOkkvNtrnXayflX74smBN--8",
    appId: "1:661570902154:android:c8ebfca9b4b6c1deda3573",
    messagingSenderId: "661570902154",
    projectId: "heritageservices-23a6c",
    storageBucket: "heritageservices-23a6c.firebasestorage.app",
  );

}
