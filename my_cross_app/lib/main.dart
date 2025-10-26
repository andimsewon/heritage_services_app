// lib/main.dart
// 앱 전체 진입점: Firebase 초기화 + 라우팅 정의
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'widgets/secure_context_warning.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    _registerViewportResyncListener();
  }

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

  // ✅ Firestore 설정 (웹 환경 최적화)
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,  // 웹 캐시 비활성화
    );
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
      
      // Service Worker 오류인 경우 특별 처리
      if (e.toString().contains('Service Worker') || 
          e.toString().contains('Secure Context')) {
        debugPrint("⚠️ Service Worker API 사용 불가 - HTTP 환경에서 실행 중");
        debugPrint("💡 해결 방법:");
        debugPrint("   1. HTTPS 환경에서 실행: flutter run -d chrome --web-tls-cert-path <cert>");
        debugPrint("   2. Firebase Hosting에 배포: flutter build web && firebase deploy");
        debugPrint("   3. 로컬 개발용 임시 해결: Chrome을 --disable-web-security로 실행");
      } else {
        debugPrint("💡 웹에서 Firebase Storage 권한을 확인해주세요.");
      }
    }
  }

  runApp(const HeritageApp());
}

class HeritageApp extends StatelessWidget {
  const HeritageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SecureContextWarning(
      child: MaterialApp(
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
        // 🔥 MaterialApp builder는 제거 - 각 화면에서 개별 처리
        // (전역 LayoutBuilder가 820px 이상에서 Infinity height 문제 발생)

        // ✅ 초기 라우트 (웹에서 '/'로 접속하면 LoginScreen으로)
        initialRoute: '/',

        // ✅ 라우트 매핑
        routes: {
          '/': (_) => const LoginScreen(), // 웹 기본 경로
          LoginScreen.route: (_) => const LoginScreen(),
          HomeScreen.route: (_) => const HomeScreen(),
          AssetSelectScreen.route: (_) => const AssetSelectScreen(),
          BasicInfoScreen.route: (_) => const BasicInfoScreen(),
          DetailSurveyScreen.route: (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return DetailSurveyScreen(
              heritageId: args?['heritageId'],
              heritageName: args?['heritageName'],
            );
          },
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
      ),
    );
  }
}

void _registerViewportResyncListener() {
  void recalcViewport() {
    final width = (html.window.innerWidth ?? 0).toDouble();
    final height = (html.window.innerHeight ?? 0).toDouble();
    ui.window.onMetricsChanged?.call();
    debugPrint('📐 Flutter viewport recalculated: ${width}x$height');
  }

  html.window.addEventListener('flutter-resize', (event) {
    recalcViewport();
  });

  // 첫 진입 시에도 뷰포트를 동기화해 회색 화면 방지
  recalcViewport();
}
