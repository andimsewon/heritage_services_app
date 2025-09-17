import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class Env {
  static String get proxyBase {
    // 웹은 항상 호스트 기준 localhost 사용
    if (kIsWeb) return 'http://127.0.0.1:8080';

    // 안드로이드 에뮬레이터는 10.0.2.2 로컬호스트 브릿지
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }

    // iOS/데스크톱은 일반 localhost
    return 'http://127.0.0.1:8080';
  }
}
