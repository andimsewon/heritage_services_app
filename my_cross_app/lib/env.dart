import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

// Web-specific imports
/// Build-time override:
/// flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
/// flutter run -d android --dart-define=API_BASE=http://10.0.2.2:8080
const String _apiBaseOverride = String.fromEnvironment('API_BASE');

class Env {
  /// Docker 컨테이너 포트
  static const String dockerPort = '8080';

  static String get proxyBase {
    // 🔍 디버그 로그 (Release 모드에서도 출력하도록 print 사용)
    print('🔍 [Env] _apiBaseOverride: "$_apiBaseOverride"');
    print('🔍 [Env] kIsWeb: $kIsWeb');
    print('🔍 [Env] Uri.base.origin: ${kIsWeb ? Uri.base.origin : "N/A"}');

    if (_apiBaseOverride.isNotEmpty) {
      print('🔍 [Env] ✅ 오버라이드 사용: $_apiBaseOverride');
      return _apiBaseOverride;
    }

    // ✅ 웹 → 현재 오리진의 Nginx 프록시(/api) 사용
    if (kIsWeb) {
      final apiUrl = '${Uri.base.origin}/api';
      print('🔍 [Env] ✅ 웹 환경: $apiUrl');
      return apiUrl;
    }

    // ✅ 안드로이드 에뮬레이터 → FastAPI 직접 연결 (8080 포트)
    // 10.0.2.2는 안드로이드 에뮬레이터에서 호스트 머신을 가리킴
    if (defaultTargetPlatform == TargetPlatform.android) {
      print('🔍 [Env] ✅ Android: http://10.0.2.2:8080');
      return 'http://10.0.2.2:8080';
    }

    // ✅ iOS 시뮬레이터/데스크톱 → FastAPI 직접 연결 (8080 포트)
    print('🔍 [Env] ✅ iOS/Desktop: http://localhost:8080');
    return 'http://localhost:8080';
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
