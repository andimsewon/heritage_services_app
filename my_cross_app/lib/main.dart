import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_cross_app/app/app.dart';
import 'package:my_cross_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
    debugPrint('Firebase already initialized, continuing...');
  }

  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );

    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.ref().child('test/connection-test.txt');
      const testData = 'Firebase Storage connection test';
      await ref.putString(testData);
      await ref.delete();
      debugPrint('✅ Firebase Storage 연결 성공!');
    } catch (e) {
      debugPrint('❌ Firebase Storage 연결 실패: $e');
      if (e.toString().contains('Service Worker') ||
          e.toString().contains('Secure Context')) {
        debugPrint('⚠️ Service Worker API 사용 불가 - HTTP 환경에서 실행 중');
        debugPrint('💡 해결 방법:');
        debugPrint('   1. HTTPS 환경에서 실행: flutter run -d chrome --web-tls-cert-path <cert>');
        debugPrint('   2. Firebase Hosting에 배포: flutter build web && firebase deploy');
        debugPrint(
            '   3. 로컬 개발용 임시 해결: Chrome을 --disable-web-security로 실행');
      } else {
        debugPrint('💡 웹에서 Firebase Storage 권한을 확인해주세요.');
      }
    }
  }

  runApp(const HeritageApp());
}
