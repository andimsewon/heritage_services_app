/// 날짜 형식 변환 유틸리티
///
/// 다양한 날짜 형식을 "YYYY년 MM월 DD일" 한국어 형식으로 변환합니다.
///
/// 지원하는 입력 형식:
/// - YYYYMMDD (8자리): "19621220" → "1962년 12월 20일"
/// - YYYY-MM-DD (ISO): "2025-10-25" → "2025년 10월 25일"
/// - YYYYMM (6자리): "202501" → "2025년 01월"
/// - YYYY (4자리): "2025" → "2025년"
/// - null/empty: "-"
String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return "-";

  // 공백 제거
  final cleaned = dateStr.trim();

  // YYYYMMDD 형식 (8자리 숫자)
  if (RegExp(r'^\d{8}$').hasMatch(cleaned)) {
    final year = cleaned.substring(0, 4);
    final month = cleaned.substring(4, 6);
    final day = cleaned.substring(6, 8);
    return "$year년 $month월 $day일";
  }

  // YYYY-MM-DD 형식 (ISO 날짜)
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleaned)) {
    final parts = cleaned.split('-');
    return "${parts[0]}년 ${parts[1]}월 ${parts[2]}일";
  }

  // YYYYMM 형식 (6자리 숫자 - 년월만)
  if (RegExp(r'^\d{6}$').hasMatch(cleaned)) {
    final year = cleaned.substring(0, 4);
    final month = cleaned.substring(4, 6);
    return "$year년 $month월";
  }

  // YYYY 형식 (4자리 숫자 - 년도만)
  if (RegExp(r'^\d{4}$').hasMatch(cleaned)) {
    return "$cleaned년";
  }

  // YYYY.MM.DD 형식 (점으로 구분)
  if (RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(cleaned)) {
    final parts = cleaned.split('.');
    return "${parts[0]}년 ${parts[1]}월 ${parts[2]}일";
  }

  // YYYY/MM/DD 형식 (슬래시로 구분)
  if (RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(cleaned)) {
    final parts = cleaned.split('/');
    return "${parts[0]}년 ${parts[1]}월 ${parts[2]}일";
  }

  // 그 외의 경우 원본 그대로 반환
  return cleaned;
}

/// 날짜 문자열이 유효한지 확인
bool isValidDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return false;

  final cleaned = dateStr.trim();

  // 지원하는 형식인지 확인
  return RegExp(r'^\d{8}$').hasMatch(cleaned) ||
         RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleaned) ||
         RegExp(r'^\d{6}$').hasMatch(cleaned) ||
         RegExp(r'^\d{4}$').hasMatch(cleaned) ||
         RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(cleaned) ||
         RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(cleaned);
}
