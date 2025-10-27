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
    this.positionTop = '-',
    this.positionMiddle = '-',
    this.positionBottom = '-',
  });

  final bool present;
  final String positionTop;    // 상 (Top)
  final String positionMiddle; // 중 (Middle)
  final String positionBottom; // 하 (Bottom)

  DamageCell copyWith({
    bool? present,
    String? positionTop,
    String? positionMiddle,
    String? positionBottom,
  }) =>
      DamageCell(
        present: present ?? this.present,
        positionTop: positionTop ?? this.positionTop,
        positionMiddle: positionMiddle ?? this.positionMiddle,
        positionBottom: positionBottom ?? this.positionBottom,
      );
}

class DamageRow {
  const DamageRow({
    required this.label,
    required this.structural,
    required this.physical,
    required this.bioChemical,
    required this.visualGrade,
    required this.labGrade,
    required this.finalGrade,
  });

  final String label;
  final Map<String, DamageCell> structural;
  final Map<String, DamageCell> physical;
  final Map<String, DamageCell> bioChemical;
  final String visualGrade;
  final String labGrade;
  final String finalGrade;

  DamageRow copyWith({
    String? label,
    Map<String, DamageCell>? structural,
    Map<String, DamageCell>? physical,
    Map<String, DamageCell>? bioChemical,
    String? visualGrade,
    String? labGrade,
    String? finalGrade,
  }) {
    return DamageRow(
      label: label ?? this.label,
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
    const structuralColumns = ['이격/이완', '기울'];
    const physicalColumns = ['탈락', '갈램'];
    const bioChemicalColumns = ['천공', '부후'];

    DamageRow makeRow(String label) => DamageRow(
      label: label,
      structural: {
        for (final column in structuralColumns) column: const DamageCell(),
      },
      physical: {
        for (final column in physicalColumns) column: const DamageCell(),
      },
      bioChemical: {
        for (final column in bioChemicalColumns) column: const DamageCell(),
      },
      visualGrade: '', // 사전 예시 데이터 제거
      labGrade: '', // 사전 예시 데이터 제거
      finalGrade: '', // 사전 예시 데이터 제거
    );

    return DamageSummary(
      rows: [], // 사전 예시 데이터 제거 - 사용자가 직접 입력
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
