class Env {
  // 웹/맥은 127.0.0.1, 안드로이드 에뮬은 10.0.2.2
  static const proxyBase = String.fromEnvironment(
    'PROXY_BASE',
    defaultValue: 'http://127.0.0.1:8080',
  );
}
