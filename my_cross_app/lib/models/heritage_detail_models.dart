import 'package:flutter/material.dart';

class InspectionResult {
  const InspectionResult({
    required this.foundation,
    required this.wall,
    required this.roof,
  });

  final String foundation;
  final String wall;
  final String roof;

  InspectionResult copyWith({String? foundation, String? wall, String? roof}) {
    return InspectionResult(
      foundation: foundation ?? this.foundation,
      wall: wall ?? this.wall,
      roof: roof ?? this.roof,
    );
  }

  factory InspectionResult.empty() =>
      const InspectionResult(foundation: '', wall: '', roof: '');
}

class DamageCell {
  const DamageCell({
    this.present = false,
    this.positionLeft = '-',
    this.positionCenter = '-',
    this.positionRight = '-',
  });

  final bool present;
  final String positionLeft;    // 좌측 (Left)
  final String positionCenter;  // 중앙 (Center)
  final String positionRight;   // 우측 (Right)

  DamageCell copyWith({
    bool? present,
    String? positionLeft,
    String? positionCenter,
    String? positionRight,
  }) =>
      DamageCell(
        present: present ?? this.present,
        positionLeft: positionLeft ?? this.positionLeft,
        positionCenter: positionCenter ?? this.positionCenter,
        positionRight: positionRight ?? this.positionRight,
      );
}

class DamageRow {
  const DamageRow({
    required this.label,
    this.partName = '',
    this.partNumber = '',
    this.direction = '',
    required this.structural,
    required this.physical,
    required this.bioChemical,
    required this.visualGrade,
    required this.labGrade,
    required this.finalGrade,
  });

  final String label;
  final String partName;      // 부재명
  final String partNumber;    // 부재번호
  final String direction;      // 향 (동향, 서향, 남향, 북향)
  final Map<String, DamageCell> structural;
  final Map<String, DamageCell> physical;
  final Map<String, DamageCell> bioChemical;
  final String visualGrade;
  final String labGrade;
  final String finalGrade;

  DamageRow copyWith({
    String? label,
    String? partName,
    String? partNumber,
    String? direction,
    Map<String, DamageCell>? structural,
    Map<String, DamageCell>? physical,
    Map<String, DamageCell>? bioChemical,
    String? visualGrade,
    String? labGrade,
    String? finalGrade,
  }) {
    return DamageRow(
      label: label ?? this.label,
      partName: partName ?? this.partName,
      partNumber: partNumber ?? this.partNumber,
      direction: direction ?? this.direction,
      structural: structural ?? this.structural,
      physical: physical ?? this.physical,
      bioChemical: bioChemical ?? this.bioChemical,
      visualGrade: visualGrade ?? this.visualGrade,
      labGrade: labGrade ?? this.labGrade,
      finalGrade: finalGrade ?? this.finalGrade,
    );
  }
}

class DamageSummary {
  const DamageSummary({
    required this.rows,
    required this.columnsStructural,
    required this.columnsPhysical,
    required this.columnsBioChemical,
  });

  final List<DamageRow> rows;
  final List<String> columnsStructural;
  final List<String> columnsPhysical;
  final List<String> columnsBioChemical;

  DamageSummary copyWith({
    List<DamageRow>? rows,
    List<String>? columnsStructural,
    List<String>? columnsPhysical,
    List<String>? columnsBioChemical,
  }) {
    return DamageSummary(
      rows: rows ?? this.rows,
      columnsStructural: columnsStructural ?? this.columnsStructural,
      columnsPhysical: columnsPhysical ?? this.columnsPhysical,
      columnsBioChemical: columnsBioChemical ?? this.columnsBioChemical,
    );
  }

  factory DamageSummary.initial() {
    // 구조적 손상: 변위/변형 (8종) + 파손/결손 (3종) = 총 11종
    const structuralColumns = [
      // 변위/변형
      '이격/이완',
      '기움',
      '들림',
      '축 변형',
      '침하',
      '처짐/휨',
      '비틀림',
      '돌아감',
      // 파손/결손
      '유실',
      '분리',
      '부러짐',
    ];
    
    // 물리적 손상: 균열/분할 (2종) + 표면 박리·박락 (3종) = 총 5종
    const physicalColumns = [
      // 균열/분할
      '균열',
      '갈래',
      // 표면 박리·박락
      '탈락',
      '들뜸',
      '박리/박락',
    ];
    
    // 생물·화학적 손상: 생물/유기물 침식 (3종) + 공극/천공 (2종) + 재료 변질 (1종) = 총 6종
    const bioChemicalColumns = [
      // 생물/유기물 침식
      '부후',
      '식물생장',
      '표면 오염균',
      // 공극/천공
      '공동화',
      '천공',
      // 재료 변질
      '변색',
    ];

    DamageRow makeRow(String label) => DamageRow(
      label: label,
      partName: '',
      partNumber: '',
      direction: '',
      structural: {
        for (final column in structuralColumns) column: const DamageCell(),
      },
      physical: {
        for (final column in physicalColumns) column: const DamageCell(),
      },
      bioChemical: {
        for (final column in bioChemicalColumns) column: const DamageCell(),
      },
      visualGrade: '',
      labGrade: '',
      finalGrade: '',
    );

    return DamageSummary(
      rows: [],
      columnsStructural: structuralColumns,
      columnsPhysical: physicalColumns,
      columnsBioChemical: bioChemicalColumns,
    );
  }
}

class InvestigatorOpinion {
  const InvestigatorOpinion({
    this.structural = '',
    this.others = '',
    this.notes = '',
    required this.opinion,
    this.date,
    this.organization,
    this.author,
  });

  final String structural;  // 구조부
  final String others;      // 기타부
  final String notes;       // 특기사항
  final String opinion;     // 조사자 종합의견
  final String? date;
  final String? organization;
  final String? author;

  InvestigatorOpinion copyWith({
    String? structural,
    String? others,
    String? notes,
    String? opinion,
    String? date,
    String? organization,
    String? author,
  }) {
    return InvestigatorOpinion(
      structural: structural ?? this.structural,
      others: others ?? this.others,
      notes: notes ?? this.notes,
      opinion: opinion ?? this.opinion,
      date: date ?? this.date,
      organization: organization ?? this.organization,
      author: author ?? this.author,
    );
  }

  factory InvestigatorOpinion.empty() => const InvestigatorOpinion(opinion: '');
}

class GradeClassification {
  const GradeClassification({required this.grade, this.label, this.summary});

  final String grade;
  final String? label;
  final String? summary;

  GradeClassification copyWith({
    String? grade,
    String? label,
    String? summary,
  }) {
    return GradeClassification(
      grade: grade ?? this.grade,
      label: label ?? this.label,
      summary: summary ?? this.summary,
    );
  }

  factory GradeClassification.initial() => const GradeClassification(
    grade: 'E',
    label: '보수정비',
    summary: '심각한 손상 양상이 확인되어 보수정비가 필요한 상태입니다.',
  );
}

class AIPredictionGrade {
  const AIPredictionGrade({
    required this.from,
    required this.to,
    required this.before,
    required this.after,
    required this.years,
  });

  final String from;
  final String to;
  final ImageProvider before;
  final ImageProvider after;
  final int years;
}

class MitigationRow {
  const MitigationRow({required this.factor, required this.action});

  final String factor;
  final String action;
}

class AIPredictionState {
  const AIPredictionState({
    this.grade,
    this.map,
    this.mitigations,
    this.loading = false,
    this.error,
  });

  final AIPredictionGrade? grade;
  final ImageProvider? map;
  final List<MitigationRow>? mitigations;
  final bool loading;
  final String? error;

  AIPredictionState copyWith({
    AIPredictionGrade? grade,
    ImageProvider? map,
    List<MitigationRow>? mitigations,
    bool? loading,
    String? error,
  }) {
    return AIPredictionState(
      grade: grade ?? this.grade,
      map: map ?? this.map,
      mitigations: mitigations ?? this.mitigations,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  factory AIPredictionState.initial() => const AIPredictionState();
}

class AIPredictionActions {
  const AIPredictionActions({
    required this.onPredictGrade,
    required this.onGenerateMap,
    required this.onSuggest,
  });

  final VoidCallback onPredictGrade;
  final VoidCallback onGenerateMap;
  final VoidCallback onSuggest;
}
