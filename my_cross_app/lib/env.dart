import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

// Web-specific imports
String _getHostname() {
  if (kIsWeb) {
    // Use Uri.base to get current URL in web
    return Uri.base.host;
  }
  return 'localhost';
}

/// Build-time override:
/// flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
/// flutter run -d android --dart-define=API_BASE=http://10.0.2.2:8080
const String _apiBaseOverride = String.fromEnvironment('API_BASE');

class Env {
  /// Docker 컨테이너 포트
  static const String dockerPort = '8080';

  static String get proxyBase {
    // 🔍 디버그 로그
    print('🔍 [Env] _apiBaseOverride: "$_apiBaseOverride"');
    print('🔍 [Env] kIsWeb: $kIsWeb');
    print('🔍 [Env] defaultTargetPlatform: $defaultTargetPlatform');

    if (_apiBaseOverride.isNotEmpty) {
      print('🔍 [Env] ✅ 오버라이드 사용: $_apiBaseOverride');
      return _apiBaseOverride;
    }

    // ✅ 웹 → Nginx 프록시를 사용하여 동일 출처(/api)로 호출
    if (kIsWeb) {
      print('🔍 [Env] ✅ 웹 환경: /api');
      return '/api';
    }

    // ✅ 안드로이드 에뮬레이터 → Nginx 프록시 (3001 포트)
    // 10.0.2.2는 안드로이드 에뮬레이터에서 호스트 머신을 가리킴
    if (defaultTargetPlatform == TargetPlatform.android) {
      print('🔍 [Env] ✅ Android: http://10.0.2.2:3001/api');
      return 'http://10.0.2.2:3001/api'; // Nginx 프록시 경유
    }

    // ✅ iOS 시뮬레이터/데스크톱 → Nginx 프록시 (3001 포트)
    print('🔍 [Env] ✅ iOS/Desktop: http://localhost:3001/api');
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
