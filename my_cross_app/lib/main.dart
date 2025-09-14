// lib/main.dart
// 앱 전체 진입점 + 라우팅 정의 (Firebase 초기화 추가)
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // ✅ Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Firestore 연결 테스트
  try {
    final fs = FirebaseFirestore.instance;
    final docRef = fs.collection('test').doc('hello');
    await docRef.set({'msg': 'Firebase 연결 성공!', 'ts': DateTime.now()});
    final snap = await docRef.get();
    print("🔥 Firestore 테스트 결과: ${snap.data()}");
  } catch (e) {
    print("❌ Firestore 테스트 실패: $e");
  }

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

      // ✅ 명시적 초기 라우트
      initialRoute: LoginScreen.route,

      // ✅ 정적 라우트 등록
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
        AssetSelectScreen.route: (_) => const AssetSelectScreen(),
        BasicInfoScreen.route: (_) => const BasicInfoScreen(),
        DetailSurveyScreen.route: (_) => const DetailSurveyScreen(),
        DamageModelScreen.route: (_) => const DamageModelScreen(),
        DamageMapPreviewScreen.route: (_) => const DamageMapPreviewScreen(),
      },

      // ✅ 동적 라우트 처리
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case LoginScreen.route:
            return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
          case HomeScreen.route:
            return MaterialPageRoute(builder: (_) => const HomeScreen(), settings: settings);
          case AssetSelectScreen.route:
            return MaterialPageRoute(builder: (_) => const AssetSelectScreen(), settings: settings);
          case BasicInfoScreen.route:
            return MaterialPageRoute(builder: (_) => const BasicInfoScreen(), settings: settings);
          case DetailSurveyScreen.route:
            return MaterialPageRoute(builder: (_) => const DetailSurveyScreen(), settings: settings);
          case DamageModelScreen.route:
            return MaterialPageRoute(builder: (_) => const DamageModelScreen(), settings: settings);
          case DamageMapPreviewScreen.route:
            return MaterialPageRoute(builder: (_) => const DamageMapPreviewScreen(), settings: settings);
        }
        return null;
      },

      // ✅ 안전망: 잘못된 라우트 처리
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('라우트 오류')),
            body: Center(
              child: Text('등록되지 않은 라우트입니다: ${settings.name}'),
            ),
          ),
        );
      },
    );
  }
}
