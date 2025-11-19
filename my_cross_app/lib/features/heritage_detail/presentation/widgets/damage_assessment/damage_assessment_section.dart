import 'package:flutter/material.dart';
import 'damage_summary_table.dart';

/// 손상 평가 종합 섹션 (간단한 래퍼)
class DamageAssessmentSection extends StatelessWidget {
  const DamageAssessmentSection({
    super.key,
    required this.heritageId,
    this.sectionNumber,
  });

  final String heritageId;
  final int? sectionNumber;

  @override
  Widget build(BuildContext context) {
    return DamageSummaryTable(
      heritageId: heritageId,
      sectionNumber: sectionNumber,
    );
  }
}

