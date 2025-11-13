// lib/core/utils/input_validator.dart
import 'dart:typed_data';

/// 입력 검증 유틸리티
class InputValidator {
  /// 문자열이 비어있지 않은지 검증
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// 문자열 길이 검증
  static bool isValidLength(String? value, {int min = 0, int max = 1000}) {
    if (value == null) return min == 0;
    final length = value.trim().length;
    return length >= min && length <= max;
  }

  /// 이메일 형식 검증
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  /// URL 형식 검증
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// 이미지 크기 검증
  static bool isValidImageSize(Uint8List? bytes, {int maxSizeMB = 10}) {
    if (bytes == null || bytes.isEmpty) return false;
    final maxBytes = maxSizeMB * 1024 * 1024;
    return bytes.length <= maxBytes;
  }

  /// 이미지 크기 검증 (에러 메시지 포함)
  static String? validateImageSize(Uint8List? bytes, {int maxSizeMB = 10}) {
    if (bytes == null || bytes.isEmpty) {
      return '이미지 데이터가 비어있습니다.';
    }
    if (!isValidImageSize(bytes, maxSizeMB: maxSizeMB)) {
      return '이미지 크기가 너무 큽니다. (최대 ${maxSizeMB}MB)';
    }
    return null;
  }

  /// Heritage ID 검증
  static String? validateHeritageId(String? heritageId) {
    if (heritageId == null || heritageId.trim().isEmpty) {
      return '문화유산 ID가 비어있습니다.';
    }
    return null;
  }

  /// 폴더명 검증
  static String? validateFolder(String? folder) {
    if (folder == null || folder.trim().isEmpty) {
      return '폴더명이 비어있습니다.';
    }
    // Firebase Storage 경로에 사용할 수 없는 문자 검증
    final invalidChars = RegExp(r'[#\[\]]');
    if (invalidChars.hasMatch(folder)) {
      return '폴더명에 사용할 수 없는 문자가 포함되어 있습니다. (#, [, ])';
    }
    return null;
  }

  /// 숫자 범위 검증
  static bool isInRange(num? value, {num min = 0, num max = 100}) {
    if (value == null) return false;
    return value >= min && value <= max;
  }

  /// 날짜 형식 검증 (ISO 8601)
  static bool isValidIsoDate(String? date) {
    if (date == null || date.isEmpty) return false;
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 여러 검증을 한 번에 수행
  static List<String> validateAll(Map<String, String?> validations) {
    final errors = <String>[];
    validations.forEach((field, error) {
      if (error != null) {
        errors.add('$field: $error');
      }
    });
    return errors;
  }
}

