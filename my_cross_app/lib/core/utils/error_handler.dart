// lib/core/utils/error_handler.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// 공통 에러 처리 유틸리티
class ErrorHandler {
  /// 에러 메시지를 사용자 친화적으로 변환
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) {
      return '알 수 없는 오류가 발생했습니다.';
    }

    final errorStr = error.toString().toLowerCase();

    // Firebase 관련 오류
    if (errorStr.contains('permission-denied')) {
      return '권한이 없습니다. Firebase 보안 규칙을 확인하세요.';
    }
    if (errorStr.contains('quota') || errorStr.contains('storage')) {
      return 'Firebase 할당량을 초과했습니다.';
    }
    if (errorStr.contains('network') || errorStr.contains('transport') || errorStr.contains('connection')) {
      return '네트워크 연결을 확인해주세요.';
    }
    if (errorStr.contains('unavailable')) {
      return '서비스를 사용할 수 없습니다. 잠시 후 다시 시도해주세요.';
    }
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return '요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
    }
    if (errorStr.contains('secure context') || errorStr.contains('service worker')) {
      return 'HTTPS 환경에서만 사용 가능합니다.';
    }

    // AI 관련 오류
    if (errorStr.contains('aimodelnotloaded') || errorStr.contains('model not loaded')) {
      return 'AI 모델이 아직 로드되지 않았습니다. 잠시 후 다시 시도해주세요.';
    }
    if (errorStr.contains('aiconnection') || errorStr.contains('ai connection')) {
      return 'AI 서버에 연결할 수 없습니다. 서버 상태를 확인해주세요.';
    }
    if (errorStr.contains('aitimeout') || errorStr.contains('ai timeout')) {
      return 'AI 서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
    }
    if (errorStr.contains('aiserverexception') || errorStr.contains('ai server') || errorStr.contains('500')) {
      return 'AI 서버에서 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }

    // 일반적인 오류
    if (errorStr.contains('argument') || errorStr.contains('invalid')) {
      return '입력값이 올바르지 않습니다.';
    }
    if (errorStr.contains('format') || errorStr.contains('parsing')) {
      return '데이터 형식이 올바르지 않습니다.';
    }
    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return '요청한 데이터를 찾을 수 없습니다.';
    }
    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return '인증이 필요합니다.';
    }
    if (errorStr.contains('forbidden') || errorStr.contains('403')) {
      return '접근 권한이 없습니다.';
    }
    if (errorStr.contains('server error') || errorStr.contains('500')) {
      return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }

    // 짧은 에러 메시지는 그대로 반환
    if (errorStr.length < 100) {
      return errorStr;
    }

    // 긴 에러 메시지는 요약
    return '오류가 발생했습니다: ${errorStr.substring(0, 50)}...';
  }

  /// 에러를 로깅하고 사용자 친화적 메시지 반환
  static String logAndGetMessage(
    dynamic error,
    String context, {
    StackTrace? stackTrace,
  }) {
    debugPrint('❌ [$context] 오류 발생: $error');
    if (stackTrace != null) {
      debugPrint('스택 트레이스: $stackTrace');
    }
    debugPrint('  - 오류 타입: ${error.runtimeType}');

    return getUserFriendlyMessage(error);
  }

  /// Firebase 에러를 분석하고 로깅
  static void logFirebaseError(
    dynamic error,
    String context, {
    StackTrace? stackTrace,
  }) {
    final errorStr = error.toString().toLowerCase();
    
    debugPrint('❌ [$context] Firebase 오류: $error');
    if (stackTrace != null) {
      debugPrint('스택 트레이스: $stackTrace');
    }
    debugPrint('  - 오류 타입: ${error.runtimeType}');

    if (errorStr.contains('permission-denied')) {
      debugPrint('🚨 권한 오류: Firestore 보안 규칙을 확인하세요!');
      debugPrint('   Firebase Console → Firestore Database → 규칙');
    } else if (errorStr.contains('network') || errorStr.contains('transport')) {
      debugPrint('🌐 네트워크 오류: 인터넷 연결을 확인하세요!');
      debugPrint('   WebChannelConnection 오류 - 네트워크 연결 문제');
    } else if (errorStr.contains('quota')) {
      debugPrint('📊 할당량 초과: Firebase 할당량을 확인하세요!');
    } else if (errorStr.contains('unavailable')) {
      debugPrint('🔧 서비스 불가: Firebase 서비스 상태를 확인하세요!');
    } else if (errorStr.contains('timeout')) {
      debugPrint('⏰ 타임아웃: 요청 시간이 초과되었습니다!');
    } else if (errorStr.contains('secure context') || errorStr.contains('service worker')) {
      debugPrint('⚠️ Secure Context 오류 감지 - HTTP 환경에서 실행 중입니다.');
      debugPrint('💡 해결 방법:');
      debugPrint('   1. HTTPS 환경에서 실행');
      debugPrint('   2. Firebase Hosting에 배포');
      debugPrint('   3. localhost에서 실행');
    }
  }

  /// 타임아웃이 있는 Future 실행
  static Future<T> withTimeout<T>(
    Future<T> future,
    Duration timeout, {
    String? context,
  }) async {
    try {
      return await future.timeout(
        timeout,
        onTimeout: () {
          if (context != null) {
            debugPrint('⏰ [$context] 타임아웃: ${timeout.inSeconds}초 초과');
          }
          throw TimeoutException('작업 시간이 초과되었습니다. (${timeout.inSeconds}초)');
        },
      );
    } on TimeoutException {
      rethrow;
    } catch (e) {
      if (context != null) {
        debugPrint('❌ [$context] 오류: $e');
      }
      rethrow;
    }
  }

  /// 안전한 타입 변환 (null 반환 가능)
  static T? safeCast<T>(dynamic value) {
    try {
      return value as T?;
    } catch (e) {
      debugPrint('⚠️ 타입 변환 실패: $value → $T');
      return null;
    }
  }

  /// 안전한 숫자 변환
  static double safeToDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    try {
      return double.parse(value.toString());
    } catch (e) {
      debugPrint('⚠️ 숫자 변환 실패: $value → double');
      return defaultValue;
    }
  }

  /// 안전한 정수 변환
  static int safeToInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    try {
      return int.parse(value.toString());
    } catch (e) {
      debugPrint('⚠️ 정수 변환 실패: $value → int');
      return defaultValue;
    }
  }

  /// 안전한 문자열 변환
  static String safeToString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  /// 안전한 리스트 변환
  static List<T> safeToList<T>(dynamic value, {List<T> defaultValue = const []}) {
    if (value == null) return defaultValue;
    if (value is List) {
      try {
        return value.cast<T>();
      } catch (e) {
        debugPrint('⚠️ 리스트 변환 실패: $value → List<$T>');
        return defaultValue;
      }
    }
    return defaultValue;
  }

  /// 안전한 맵 변환
  static Map<String, dynamic> safeToMap(dynamic value, {Map<String, dynamic> defaultValue = const {}}) {
    if (value == null) return defaultValue;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (e) {
        debugPrint('⚠️ 맵 변환 실패: $value → Map<String, dynamic>');
        return defaultValue;
      }
    }
    return defaultValue;
  }
}

