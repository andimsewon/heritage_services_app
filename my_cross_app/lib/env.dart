import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Build-time override:
/// flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
const String _apiBaseOverride = String.fromEnvironment('API_BASE');

class Env {
  static String get proxyBase {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    // 웹은 항상 호스트 기준 localhost 사용
    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      return 'http://$host:8080';
    }

    // 안드로이드 에뮬레이터는 10.0.2.2 로컬호스트 브릿지
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }

    // iOS/데스크톱은 일반 localhost
    return 'http://127.0.0.1:8080';
  }
}
