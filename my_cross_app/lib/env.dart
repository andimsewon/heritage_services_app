import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform, debugPrint;

// Web-specific imports
/// Build-time override:
/// flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
/// flutter run -d android --dart-define=API_BASE=http://10.0.2.2:8080
const String _apiBaseOverride = String.fromEnvironment('API_BASE');

class Env {
  /// Docker 컨테이너 포트
  static const String dockerPort = '8080';

  static String get proxyBase {
    // 🔍 디버그 로그
    if (kDebugMode) debugPrint('🔍 [Env] _apiBaseOverride: "$_apiBaseOverride"');
    if (kDebugMode) debugPrint('🔍 [Env] kIsWeb: $kIsWeb');
    if (kDebugMode) debugPrint('🔍 [Env] defaultTargetPlatform: $defaultTargetPlatform');

    if (_apiBaseOverride.isNotEmpty) {
      if (kDebugMode) debugPrint('🔍 [Env] ✅ 오버라이드 사용: $_apiBaseOverride');
      return _apiBaseOverride;
    }

    // ✅ 웹 → 현재 오리진의 Nginx 프록시(/api) 사용
    if (kIsWeb) {
      final apiUrl = '${Uri.base.origin}/api';
      if (kDebugMode) debugPrint('🔍 [Env] ✅ 웹 환경: $apiUrl');
      return apiUrl;
    }

    // ✅ 안드로이드 에뮬레이터 → Nginx 프록시 (3001 포트)
    // 10.0.2.2는 안드로이드 에뮬레이터에서 호스트 머신을 가리킴
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (kDebugMode) debugPrint('🔍 [Env] ✅ Android: http://10.0.2.2:3001/api');
      return 'http://10.0.2.2:3001/api';
    }

    // ✅ iOS 시뮬레이터/데스크톱 → Nginx 프록시 (3001 포트)
    if (kDebugMode) debugPrint('🔍 [Env] ✅ iOS/Desktop: http://localhost:3001/api');
    return 'http://localhost:3001/api';
  }

  /// 원격 서버 URL (프로덕션 배포용)
  static String get remoteServerUrl {
    return '/api';
  }

  /// 현재 사용 중인 서버 URL 반환
  static String get actualServerUrl {
    return proxyBase;
  }
}
