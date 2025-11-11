import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:my_cross_app/app/router.dart';
import 'package:my_cross_app/core/theme/app_theme.dart';
import 'package:my_cross_app/core/widgets/secure_context_warning.dart';

class HeritageApp extends StatelessWidget {
  const HeritageApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter();
    return SecureContextWarning(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '국가유산 모니터링',
        theme: AppTheme.light(isWeb: kIsWeb),
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        initialRoute: AppRouter.initialRoute,
        routes: router.routes,
        onGenerateRoute: router.onGenerateRoute,
        onUnknownRoute: router.onUnknownRoute,
      ),
    );
  }
}
