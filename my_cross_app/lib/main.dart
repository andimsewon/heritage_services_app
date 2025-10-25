// lib/main.dart
// 앱 전체 진입점: Firebase 초기화 + 라우팅 정의
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
      debugPrint('Firebase already initialized, continuing...');
    } else {
      rethrow;
    }
  }

  // 🔎 Firebase Storage 연결 테스트 (웹 환경에서 권한 확인)
  if (kIsWeb) {
    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.ref().child('test/connection-test.txt');

      // 작은 테스트 파일 업로드 시도
      const testData = 'Firebase Storage connection test';
      await ref.putString(testData);

      // 업로드된 파일 삭제
      await ref.delete();

      debugPrint("✅ Firebase Storage 연결 성공!");
    } catch (e) {
      debugPrint("❌ Firebase Storage 연결 실패: $e");
      debugPrint("💡 웹에서 Firebase Storage 권한을 확인해주세요.");
    }
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        // 버튼들을 사각형 형태로 통일
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        chipTheme: const ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
        ),
        // 웹 환경에서 시스템 폰트 사용
        fontFamily: kIsWeb ? 'system-ui' : null,
      ),
      // 마우스 드래그로도 스크롤 가능하도록 설정 (웹의 가로 스크롤 UX 개선)
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
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
