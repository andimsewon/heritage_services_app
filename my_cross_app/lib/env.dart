import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Build-time override:
/// flutter run -d chrome --dart-define=API_BASE=http://210.117.181.115:8080
const String _apiBaseOverride = String.fromEnvironment('API_BASE');

class Env {
  static String get proxyBase {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;

    // ✅ 웹은 CORS 프록시 서버 사용
    if (kIsWeb) {
      return 'http://localhost:3000/api'; // 로컬 프록시 서버
    }

    // ✅ 안드로이드 에뮬레이터 → 원격 서버 직접 접근
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://210.117.181.115:8080';
    }

    // ✅ iOS/데스크톱 → 원격 서버 직접 접근
    return 'http://210.117.181.115:8080';
  }

  /// 웹 환경에서 실제 서버 URL (프록시 설정용)
  static String get actualServerUrl {
    return 'http://210.117.181.115:8080';
  }
}
