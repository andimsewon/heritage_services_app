// lib/main.dart
// 앱 전체 진입점 + 라우팅 정의 (보강: onGenerateRoute / onUnknownRoute)

import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/asset_select_screen.dart';
import 'screens/basic_info_screen.dart';
import 'screens/detail_survey_screen.dart';
import 'screens/damage_model_screen.dart';
import 'screens/damage_map_preview_screen.dart';

void main() {
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
        LoginScreen.route: (_) => const LoginScreen(),                 // ① 로그인
        HomeScreen.route: (_) => const HomeScreen(),                   // ② 홈
        AssetSelectScreen.route: (_) => const AssetSelectScreen(),     // ③ 국유재 선택
        BasicInfoScreen.route: (_) => const BasicInfoScreen(),         // ④ 기본정보 입력
        DetailSurveyScreen.route: (_) => const DetailSurveyScreen(),   // ⑤ 상세조사
        DamageModelScreen.route: (_) => const DamageModelScreen(),     // ⑥ 손상예측/모델
        DamageMapPreviewScreen.route: (_) => const DamageMapPreviewScreen(), // ⑦ 손상지도
      },

      // ✅ 예비: 동적/미등록 라우트 처리 (인자 전달 시 유용)
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
        return null; // 모르면 아래 onUnknownRoute로
      },

      // ✅ 안전망: 잘못된 이름으로 pushNamed 했을 때
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
