// lib/env.dart
class Env {
  static const proxyBase = String.fromEnvironment(
    'PROXY_BASE',
    // 안드로이드 에뮬: 10.0.2.2, iOS 시뮬레이터/웹: 127.0.0.1
    defaultValue: 'http://10.0.2.2:8080',
  );
}
