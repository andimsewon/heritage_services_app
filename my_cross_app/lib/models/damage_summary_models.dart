/// 손상부 조사 기록 모델 (Firestore에서 로드된 원본 데이터)
class DamageRecord {
  const DamageRecord({
    required this.id,
    required this.heritageId,
    this.componentId,
    this.partName,
    this.partNumber,
    this.direction,
    this.position, // 좌측, 중앙, 우측
    required this.category, // structural, physical, biochemical
    required this.subType, // 이격/이완, 기울, 탈락 등
    this.timestamp,
  });

  final String id;
  final String heritageId;
  final String? componentId;
  final String? partName;
  final String? partNumber;
  final String? direction;
  final String? position; // 좌측, 중앙, 우측
  final DamageCategory category;
  final String subType;
  final DateTime? timestamp;

  factory DamageRecord.fromFirestore(Map<String, dynamic> data, String docId) {
    // position을 좌측/중앙/우측으로 매핑
    String? mapPosition(String? pos) {
      if (pos == null) return null;
      // 상/중/하를 좌/중/우로 매핑 (필요시 조정)
      switch (pos) {
        case '상':
        case '좌':
        case '좌측':
          return '좌측';
        case '중':
        case '중앙':
          return '중앙';
        case '하':
        case '우':
        case '우측':
          return '우측';
        default:
          return pos;
      }
    }

    // category 매핑
    DamageCategory mapCategory(String? categoryStr, String? phenomenon) {
      if (categoryStr != null) {
        switch (categoryStr.toLowerCase()) {
          case 'structural':
          case '구조적':
            return DamageCategory.structural;
          case 'physical':
          case '물리적':
            return DamageCategory.physical;
          case 'biochemical':
          case '생물·화학적':
          case '생물화학적':
            return DamageCategory.biochemical;
        }
      }
      // phenomenon으로 추론
      if (phenomenon != null) {
        final lower = phenomenon.toLowerCase();
        if (lower.contains('이격') || lower.contains('이완') || lower.contains('기울') ||
            lower.contains('들림') || lower.contains('변형') || lower.contains('침하') ||
            lower.contains('처짐') || lower.contains('비틀림') || lower.contains('돌아감') ||
            lower.contains('유실') || lower.contains('분리') || lower.contains('부러짐')) {
          return DamageCategory.structural;
        }
        if (lower.contains('균열') || lower.contains('갈래') || lower.contains('탈락') ||
            lower.contains('들뜸') || lower.contains('박리') || lower.contains('박락')) {
          return DamageCategory.physical;
        }
        if (lower.contains('부후') || lower.contains('식물') || lower.contains('오염') ||
            lower.contains('공동') || lower.contains('천공') || lower.contains('변색')) {
          return DamageCategory.biochemical;
        }
      }
      return DamageCategory.structural; // 기본값
    }

    return DamageRecord(
      id: docId,
      heritageId: data['heritageId'] as String? ?? '',
      componentId: data['componentId'] as String?,
      partName: data['partName'] as String?,
      partNumber: data['partNumber'] as String?,
      direction: data['direction'] as String?,
      position: mapPosition(data['position'] as String?),
      category: mapCategory(
        data['category'] as String?,
        data['phenomenon'] as String?,
      ),
      subType: data['subType'] as String? ?? data['phenomenon'] as String? ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'heritageId': heritageId,
      if (componentId != null) 'componentId': componentId,
      if (partName != null) 'partName': partName,
      if (partNumber != null) 'partNumber': partNumber,
      if (direction != null) 'direction': direction,
      if (position != null) 'position': position,
      'category': category.name,
      'subType': subType,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }
}

/// 손상 카테고리
enum DamageCategory {
  structural, // 구조적 손상
  physical,   // 물리적 손상
  biochemical, // 생물·화학적 손상
}

/// 손상부 종합 요약 모델 (Firestore 저장용)
class DamageSummaryData {
  const DamageSummaryData({
    required this.heritageId,
    required this.componentId,
    required this.componentName, // 부재명 + 부재번호 + 향
    required this.structural,    // { "이격/이완": "O/X/O", ... }
    required this.physical,       // { "탈락": "X/O/X", ... }
    required this.biochemical,    // { "부후": "O/X/O", ... }
    this.grades,                 // { "visual": "A", "advanced": "B" }
    this.timestamp,
  });

  final String heritageId;
  final String componentId;
  final String componentName;
  final Map<String, String> structural;    // subtype -> "O/X/O"
  final Map<String, String> physical;       // subtype -> "O/X/O"
  final Map<String, String> biochemical;    // subtype -> "O/X/O"
  final Map<String, String>? grades;
  final DateTime? timestamp;

  factory DamageSummaryData.fromFirestore(Map<String, dynamic> data) {
    return DamageSummaryData(
      heritageId: data['heritageId'] as String? ?? '',
      componentId: data['componentId'] as String? ?? '',
      componentName: data['componentName'] as String? ?? '',
      structural: Map<String, String>.from(data['structural'] as Map? ?? {}),
      physical: Map<String, String>.from(data['physical'] as Map? ?? {}),
      biochemical: Map<String, String>.from(data['biochemical'] as Map? ?? {}),
      grades: data['grades'] != null
          ? Map<String, String>.from(data['grades'] as Map)
          : null,
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heritageId': heritageId,
      'componentId': componentId,
      'componentName': componentName,
      'structural': structural,
      'physical': physical,
      'biochemical': biochemical,
      if (grades != null) 'grades': grades,
      'timestamp': timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  DamageSummaryData copyWith({
    String? heritageId,
    String? componentId,
    String? componentName,
    Map<String, String>? structural,
    Map<String, String>? physical,
    Map<String, String>? biochemical,
    Map<String, String>? grades,
    DateTime? timestamp,
  }) {
    return DamageSummaryData(
      heritageId: heritageId ?? this.heritageId,
      componentId: componentId ?? this.componentId,
      componentName: componentName ?? this.componentName,
      structural: structural ?? this.structural,
      physical: physical ?? this.physical,
      biochemical: biochemical ?? this.biochemical,
      grades: grades ?? this.grades,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// 손상등급 데이터
class DamageGrade {
  const DamageGrade({
    required this.componentId,
    this.visualGrade,
    this.advancedGrade,
  });

  final String componentId;
  final String? visualGrade;    // 육안 등급
  final String? advancedGrade;  // 심화 등급

  factory DamageGrade.fromMap(Map<String, dynamic> data) {
    return DamageGrade(
      componentId: data['componentId'] as String? ?? '',
      visualGrade: data['visualGrade'] as String?,
      advancedGrade: data['advancedGrade'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'componentId': componentId,
      if (visualGrade != null) 'visualGrade': visualGrade,
      if (advancedGrade != null) 'advancedGrade': advancedGrade,
    };
  }
}

