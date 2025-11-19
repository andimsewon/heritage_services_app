/// 손상 등급 계산 로직
/// 
/// 비즈니스 규칙:
/// - O/X 손상표에서 각 셀은 "O", "X", 또는 "O/X/O" 형식
/// - "O"가 하나라도 있으면 해당 카테고리는 손상 있음
/// - 모든 것이 "X"면 손상 없음

class DamageGradeCalculator {
  /// 육안 등급 계산
  /// 
  /// 규칙:
  /// - 모든 카테고리가 X → A
  /// - 1개 카테고리만 O → B
  /// - 2개 이상 카테고리 O → C
  /// - 3개 이상 O 또는 여러 주요 그룹(구조+물리 등) → D
  static String calculateVisualGrade(Map<String, String> oxValues) {
    if (oxValues.isEmpty) return 'A';

    // 각 카테고리별 손상 여부 확인
    final damagedCategories = <String>[];
    
    for (final entry in oxValues.entries) {
      final value = entry.value.trim().toUpperCase();
      // "O"가 하나라도 있으면 손상 있음
      if (value.contains('O')) {
        damagedCategories.add(entry.key);
      }
    }

    if (damagedCategories.isEmpty) {
      return 'A'; // 손상 없음
    }

    // 손상된 카테고리 수
    final damageCount = damagedCategories.length;

    // 주요 그룹 확인 (구조적, 물리적, 생화학적)
    final hasStructural = _hasDamageInGroup(oxValues, _structuralColumns);
    final hasPhysical = _hasDamageInGroup(oxValues, _physicalColumns);
    final hasBiochemical = _hasDamageInGroup(oxValues, _biochemicalColumns);

    // 여러 주요 그룹에 손상이 있는지 확인
    final groupCount = [
      hasStructural,
      hasPhysical,
      hasBiochemical,
    ].where((has) => has).length;

    // 총 O 개수 계산 (모든 셀의 O 개수)
    int totalOCount = 0;
    for (final value in oxValues.values) {
      totalOCount += value.toUpperCase().split('').where((c) => c == 'O').length;
    }

    // 등급 산정
    if (totalOCount >= 3 || groupCount >= 2) {
      return 'D'; // 심각하거나 광범위한 손상
    } else if (damageCount >= 2) {
      return 'C'; // 2개 이상 카테고리 손상
    } else if (damageCount == 1) {
      return 'B'; // 1개 카테고리만 손상 (경미)
    } else {
      return 'A'; // 손상 없음 (이론적으로 도달 불가)
    }
  }

  /// 심화 등급 계산
  /// 
  /// 규칙 (더 엄격):
  /// - 구조적 손상 있으면 최소 C
  /// - 구조 + 물리 또는 구조 + 생화학 → D
  /// - 경미한 물리/생화학만 → B
  /// - 손상 없음 → A
  static String calculateAdvancedGrade(Map<String, String> oxValues) {
    if (oxValues.isEmpty) return 'A';

    // 주요 그룹별 손상 여부
    final hasStructural = _hasDamageInGroup(oxValues, _structuralColumns);
    final hasPhysical = _hasDamageInGroup(oxValues, _physicalColumns);
    final hasBiochemical = _hasDamageInGroup(oxValues, _biochemicalColumns);

    // 구조적 손상이 있으면 최소 C
    if (hasStructural) {
      // 구조 + 물리 또는 구조 + 생화학 → D
      if (hasPhysical || hasBiochemical) {
        return 'D';
      }
      // 구조적 손상만 → C
      return 'C';
    }

    // 구조적 손상 없음
    if (hasPhysical || hasBiochemical) {
      // 경미한 물리/생화학 손상만 → B
      // 여러 카테고리에 손상이 있으면 C
      final physicalCount = _countDamagedColumns(oxValues, _physicalColumns);
      final biochemicalCount = _countDamagedColumns(oxValues, _biochemicalColumns);
      
      if (physicalCount + biochemicalCount >= 2) {
        return 'C';
      }
      return 'B';
    }

    // 손상 없음
    return 'A';
  }

  /// 특정 그룹에 손상이 있는지 확인
  static bool _hasDamageInGroup(
    Map<String, String> oxValues,
    List<String> groupColumns,
  ) {
    for (final column in groupColumns) {
      final value = oxValues[column]?.trim().toUpperCase() ?? '';
      if (value.contains('O')) {
        return true;
      }
    }
    return false;
  }

  /// 특정 그룹에서 손상된 컬럼 수 계산
  static int _countDamagedColumns(
    Map<String, String> oxValues,
    List<String> groupColumns,
  ) {
    int count = 0;
    for (final column in groupColumns) {
      final value = oxValues[column]?.trim().toUpperCase() ?? '';
      if (value.contains('O')) {
        count++;
      }
    }
    return count;
  }

  /// 구조적 손상 컬럼 목록
  static const List<String> _structuralColumns = [
    '이격/이완',
    '기울',
    '기타 구조항목',
  ];

  /// 물리적 손상 컬럼 목록
  static const List<String> _physicalColumns = [
    '탈락',
    '갈램',
    '기타 물리항목',
  ];

  /// 생물·화학적 손상 컬럼 목록
  static const List<String> _biochemicalColumns = [
    '천공',
    '부후',
    '기타 생화학항목',
  ];

  /// 구조적 손상 컬럼 목록 반환
  static List<String> getStructuralColumns() {
    return List.unmodifiable(_structuralColumns);
  }

  /// 물리적 손상 컬럼 목록 반환
  static List<String> getPhysicalColumns() {
    return List.unmodifiable(_physicalColumns);
  }

  /// 생물·화학적 손상 컬럼 목록 반환
  static List<String> getBiochemicalColumns() {
    return List.unmodifiable(_biochemicalColumns);
  }

  /// 모든 컬럼 목록
  static List<String> getAllColumns() {
    return [
      ..._structuralColumns,
      ..._physicalColumns,
      ..._biochemicalColumns,
    ];
  }

  /// O/X 값 검증
  /// 
  /// 허용되는 문자: O, X, /, 공백
  static bool isValidOxValue(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return true; // 빈 값 허용
    
    // O, X, /, 공백만 허용
    final validChars = RegExp(r'^[OX/\s]+$');
    return validChars.hasMatch(normalized);
  }

  /// O/X 값을 정규화 (대문자, 공백 제거)
  static String normalizeOxValue(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }
}

