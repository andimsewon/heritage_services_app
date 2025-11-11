import 'package:flutter/material.dart';
import 'package:my_cross_app/features/auth/presentation/login_screen.dart';
import 'package:my_cross_app/features/dashboard/presentation/home_screen.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/basic_info_screen.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/damage_map_preview_screen.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/damage_model_screen.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/damage_survey_with_detail_screen.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/detail_survey_screen.dart';
import 'package:my_cross_app/features/heritage_list/presentation/asset_select_screen.dart';

class AppRouter {
  static const initialRoute = '/';

  Map<String, WidgetBuilder> get routes => {
        '/': (_) => const LoginScreen(),
        LoginScreen.route: (_) => const LoginScreen(),
        HomeScreen.route: (_) => const HomeScreen(),
        AssetSelectScreen.route: (_) => const AssetSelectScreen(),
        BasicInfoScreen.route: (_) => const BasicInfoScreen(),
        DamageModelScreen.route: (_) => const DamageModelScreen(),
        DamageMapPreviewScreen.route: (_) => const DamageMapPreviewScreen(),
        DamageSurveyWithDetailScreen.route: (_) =>
            const DamageSurveyWithDetailScreen(),
      };

  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case DetailSurveyScreen.route:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DetailSurveyScreen(
            heritageId: args?['heritageId'] as String?,
            heritageName: args?['heritageName'] as String?,
          ),
          settings: settings,
        );
    }
    return null;
  }

  Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('라우트 오류')),
        body: Center(
          child: Text('등록되지 않은 라우트입니다: ${settings.name}'),
        ),
      ),
      settings: settings,
    );
  }
}
