// lib/utils/position_options.dart
// 구조적 위치 입력 표준화 유틸리티

class PositionOptions {
  // 부재별 위치 옵션 정의
  static const Map<String, List<String>> positionOptions = {
    '기둥': ['상', '중', '하'],
    '보': ['좌', '중', '우'],
    '벽체': ['상', '중', '하'],
    '지붕': ['좌', '중', '우'],
    '기단': ['상', '중', '하'],
    '대들보': ['좌', '중', '우'],
    '도리': ['좌', '중', '우'],
    '서까래': ['상', '중', '하'],
    '마루': ['좌', '중', '우'],
    '천장': ['좌', '중', '우'],
  };

  // 기본 위치 옵션 (부재가 명시되지 않은 경우)
  static const List<String> defaultPositions = ['상', '중', '하'];

  // 부재명으로 위치 옵션 가져오기
  static List<String> getPositionsForMember(String memberName) {
    // 부재명에서 키워드 찾기
    for (final entry in positionOptions.entries) {
      if (memberName.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // 기본값 반환
    return defaultPositions;
  }

  // 부재 유형별 위치 옵션 가져오기
  static List<String> getPositionsByType(String memberType) {
    return positionOptions[memberType] ?? defaultPositions;
  }

  // 모든 가능한 위치 옵션
  static List<String> getAllPositions() {
    final allPositions = <String>{};
    for (final positions in positionOptions.values) {
      allPositions.addAll(positions);
    }
    return allPositions.toList()..sort();
  }

  // 위치 옵션 유효성 검사
  static bool isValidPosition(String memberType, String position) {
    final validPositions = getPositionsByType(memberType);
    return validPositions.contains(position);
  }

  // 위치 표시 텍스트 생성
  static String getPositionDisplayText(String memberType, String position) {
    if (memberType == '보' || memberType == '지붕' || memberType == '대들보' || 
        memberType == '도리' || memberType == '마루' || memberType == '천장') {
      switch (position) {
        case '좌': return '좌측';
        case '중': return '중앙';
        case '우': return '우측';
        default: return position;
      }
    } else {
      switch (position) {
        case '상': return '상부';
        case '중': return '중부';
        case '하': return '하부';
        default: return position;
      }
    }
  }

  // Firestore 저장용 필드명 생성
  static String getPositionFieldName(String position) {
    switch (position) {
      case '상': case '좌': return 'positionTop';
      case '중': return 'positionMiddle';
      case '하': case '우': return 'positionBottom';
      default: return 'positionOther';
    }
  }

  // 위치별 색상 (시각적 구분용)
  static int getPositionColor(String position) {
    switch (position) {
      case '상': case '좌': return 0xFF4CAF50; // Green
      case '중': return 0xFF2196F3; // Blue
      case '하': case '우': return 0xFFFF9800; // Orange
      default: return 0xFF9E9E9E; // Grey
    }
  }
}
