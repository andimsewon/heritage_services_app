// lib/widgets/secure_context_warning.dart
import 'package:flutter/material.dart';

/// HTTP 환경에서 Service Worker 오류를 감지하고 사용자에게 안내하는 위젯
///
/// 웹 환경에서만 작동하며, Firebase Storage 등의 기능이 제한될 수 있는 경우
/// 사용자에게 HTTPS 환경으로 이동하도록 안내합니다.
class SecureContextWarning extends StatelessWidget {
  final Widget child;

  const SecureContextWarning({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 현재는 Firebase 오류가 이미 적절하게 처리되고 있으므로
    // 추가 경고 UI 없이 child만 반환합니다.
    // 나중에 필요하면 이 위젯에 경고 UI를 추가할 수 있습니다.
    return child;
  }
}
