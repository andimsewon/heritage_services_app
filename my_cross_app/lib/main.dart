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
    // 웹 성능 최적화: Firestore 설정만 빠르게 적용
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    // Firebase Storage 연결 테스트는 비동기로 지연 (앱 시작 속도 향상)
    Future.microtask(() async {
      try {
        final storage = FirebaseStorage.instance;
        final ref = storage.ref().child('test/connection-test.txt');
        const testData = 'Firebase Storage connection test';
        await ref.putString(testData);
        await ref.delete();
        if (kDebugMode) {
          debugPrint('✅ Firebase Storage 연결 성공!');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Firebase Storage 연결 실패: $e');
        }
      }
    });
  }

  runApp(const HeritageApp());
}
