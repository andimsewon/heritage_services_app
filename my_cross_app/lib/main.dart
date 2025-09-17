// lib/main.dart
// 앱 전체 진입점: Firebase 초기화 + 라우팅 정의
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/asset_select_screen.dart';
import 'screens/basic_info_screen.dart';
import 'screens/detail_survey_screen.dart';
import 'screens/damage_model_screen.dart';
import 'screens/damage_map_preview_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase 초기화 (중복 방지)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase가 이미 초기화된 경우 무시
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, continuing...');
    } else {
      rethrow;
    }
  }

  // 🔎 Firestore 연결 테스트 (원할 때만 주석 해제)
  /*
  try {
    final fs = FirebaseFirestore.instance;
    final docRef = fs.collection('test').doc('hello');
    await docRef.set({'msg': 'Firebase 연결 성공!', 'ts': DateTime.now()});
    final snap = await docRef.get();
    print("🔥 Firestore 테스트 결과: ${snap.data()}");
  } catch (e) {
    print("❌ Firestore 테스트 실패: $e");
  }
  */

  runApp(const HeritageApp());
}

class HeritageApp extends StatelessWidget {
  const HeritageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '국가유산 모니터링',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),

      // ✅ 초기 라우트
      initialRoute: LoginScreen.route,

      // ✅ 라우트 매핑
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
        AssetSelectScreen.route: (_) => const AssetSelectScreen(),
        BasicInfoScreen.route: (_) => const BasicInfoScreen(),
        DetailSurveyScreen.route: (_) => const DetailSurveyScreen(),
        DamageModelScreen.route: (_) => const DamageModelScreen(),
        DamageMapPreviewScreen.route: (_) => const DamageMapPreviewScreen(),
      },

      // ✅ 잘못된 라우트 진입 시 처리
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('라우트 오류')),
            body: Center(child: Text('등록되지 않은 라우트입니다: ${settings.name}')),
          ),
        );
      },
    );
  }
}
