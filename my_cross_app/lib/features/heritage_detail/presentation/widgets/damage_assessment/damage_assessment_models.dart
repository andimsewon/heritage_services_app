/// 손상 평가 데이터 모델

/// 구성 요소별 O/X 손상 데이터
class ComponentOxData {
  final String componentId;
  final String componentName; // 예: "기둥 02번 (서)"
  final Map<String, String> oxValues; // 컬럼 ID → O/X 값

  ComponentOxData({
    required this.componentId,
    required this.componentName,
    Map<String, String>? oxValues,
  }) : oxValues = oxValues ?? {};

  ComponentOxData copyWith({
    String? componentId,
    String? componentName,
    Map<String, String>? oxValues,
  }) {
    return ComponentOxData(
      componentId: componentId ?? this.componentId,
      componentName: componentName ?? this.componentName,
      oxValues: oxValues ?? Map<String, String>.from(this.oxValues),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'componentId': componentId,
      'componentName': componentName,
      'oxValues': oxValues,
    };
  }

  factory ComponentOxData.fromMap(Map<String, dynamic> map) {
    return ComponentOxData(
      componentId: map['componentId'] ?? '',
      componentName: map['componentName'] ?? '',
      oxValues: Map<String, String>.from(
        map['oxValues'] ?? {},
      ),
    );
  }
}

/// 구성 요소별 등급 데이터
class ComponentGradeData {
  final String componentId;
  final String visualGrade; // A, B, C, D
  final String advancedGrade; // A, B, C, D
  final DateTime? lastUpdated;
  final bool isManualOverride; // 수동 오버라이드 여부

  ComponentGradeData({
    required this.componentId,
    this.visualGrade = 'A',
    this.advancedGrade = 'A',
    this.lastUpdated,
    this.isManualOverride = false,
  });

  ComponentGradeData copyWith({
    String? componentId,
    String? visualGrade,
    String? advancedGrade,
    DateTime? lastUpdated,
    bool? isManualOverride,
  }) {
    return ComponentGradeData(
      componentId: componentId ?? this.componentId,
      visualGrade: visualGrade ?? this.visualGrade,
      advancedGrade: advancedGrade ?? this.advancedGrade,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isManualOverride: isManualOverride ?? this.isManualOverride,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'componentId': componentId,
      'visualGrade': visualGrade,
      'advancedGrade': advancedGrade,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'isManualOverride': isManualOverride,
    };
  }

  factory ComponentGradeData.fromMap(Map<String, dynamic> map) {
    return ComponentGradeData(
      componentId: map['componentId'] ?? '',
      visualGrade: map['visualGrade'] ?? 'A',
      advancedGrade: map['advancedGrade'] ?? 'A',
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.parse(map['lastUpdated'])
          : null,
      isManualOverride: map['isManualOverride'] ?? false,
    );
  }
}

/// 손상 평가 요약 데이터 (전체)
class DamageAssessmentSummary {
  final Map<String, ComponentOxData> oxTable; // componentId → ComponentOxData
  final Map<String, ComponentGradeData> grades; // componentId → ComponentGradeData
  final bool autoGradeEnabled; // 자동 등급 계산 활성화 여부

  DamageAssessmentSummary({
    Map<String, ComponentOxData>? oxTable,
    Map<String, ComponentGradeData>? grades,
    this.autoGradeEnabled = true,
  })  : oxTable = oxTable ?? {},
        grades = grades ?? {};

  DamageAssessmentSummary copyWith({
    Map<String, ComponentOxData>? oxTable,
    Map<String, ComponentGradeData>? grades,
    bool? autoGradeEnabled,
  }) {
    return DamageAssessmentSummary(
      oxTable: oxTable ?? Map<String, ComponentOxData>.from(this.oxTable),
      grades: grades ?? Map<String, ComponentGradeData>.from(this.grades),
      autoGradeEnabled: autoGradeEnabled ?? this.autoGradeEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'oxTable': oxTable.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'grades': grades.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'autoGradeEnabled': autoGradeEnabled,
    };
  }

  factory DamageAssessmentSummary.fromMap(Map<String, dynamic> map) {
    final oxTableMap = map['oxTable'] as Map<String, dynamic>? ?? {};
    final gradesMap = map['grades'] as Map<String, dynamic>? ?? {};

    return DamageAssessmentSummary(
      oxTable: oxTableMap.map(
        (key, value) => MapEntry(
          key,
          ComponentOxData.fromMap(Map<String, dynamic>.from(value)),
        ),
      ),
      grades: gradesMap.map(
        (key, value) => MapEntry(
          key,
          ComponentGradeData.fromMap(Map<String, dynamic>.from(value)),
        ),
      ),
      autoGradeEnabled: map['autoGradeEnabled'] ?? true,
    );
  }

  /// 빈 데이터로 초기화
  factory DamageAssessmentSummary.initial() {
    return DamageAssessmentSummary();
  }
}

