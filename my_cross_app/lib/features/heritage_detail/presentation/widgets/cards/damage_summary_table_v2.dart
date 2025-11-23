import 'package:flutter/material.dart';
import 'package:my_cross_app/core/ui/widgets/responsive_table.dart';
import 'package:my_cross_app/models/heritage_detail_models.dart';

/// 손상부 종합 테이블 (UI 시안 기반)
/// 실제 입력 데이터를 그대로 반영하는 미리보기 버전
class DamageSummaryTableV2 extends StatelessWidget {
  const DamageSummaryTableV2({super.key, required this.value});

  final DamageSummary value;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900;
    final hasRows = value.rows.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: const Text(
            '손상부 종합',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            '* 손상이 탐지된 경우 O / 아닌 경우 X 로 표기',
            style: TextStyle(color: Colors.red, fontSize: isCompact ? 11 : 12),
          ),
        ),
        if (!hasRows)
          _buildEmptyState(isCompact)
        else
          ResponsiveTable(
            minWidth: _previewMinWidth(),
            child: _buildTable(isCompact),
          ),
      ],
    );
  }

  Widget _buildEmptyState(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Text(
        '입력된 손상부 데이터가 없습니다. 상단 표에서 손상을 추가하면 미리보기가 생성됩니다.',
        style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
      ),
    );
  }

  double _previewMinWidth() {
    final columnCount =
        1 +
        (value.columnsStructural.length + 1) +
        (value.columnsPhysical.length + 1) +
        (value.columnsBioChemical.length + 1) +
        1;
    return columnCount * 100.0;
  }

  Widget _buildTable(bool isCompact) {
    return Table(
      border: TableBorder.all(color: Colors.black26, width: 1),
      defaultColumnWidth: isCompact
          ? const FixedColumnWidth(80)
          : const FixedColumnWidth(110),
      children: [
        _buildHeaderRow(isCompact),
        _buildSubHeaderRow(isCompact),
        ...value.rows.map((row) => _buildDataRow(row, isCompact)),
      ],
    );
  }

  TableRow _buildHeaderRow(bool isCompact) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFF333333)),
      children: [
        _tableCell(
          '손상 유형',
          bold: true,
          textColor: Colors.white,
          fontSize: isCompact ? 11 : 14,
        ),
        ...List.generate(
          value.columnsStructural.length + 1,
          (index) => index == 0
              ? _tableCell(
                  '구조적 손상',
                  bold: true,
                  textColor: Colors.white,
                  fontSize: isCompact ? 11 : 14,
                )
              : _tableCell('', fontSize: isCompact ? 11 : 14),
        ),
        ...List.generate(
          value.columnsPhysical.length + 1,
          (index) => index == 0
              ? _tableCell(
                  '물리적 손상',
                  bold: true,
                  textColor: Colors.white,
                  fontSize: isCompact ? 11 : 14,
                )
              : _tableCell('', fontSize: isCompact ? 11 : 14),
        ),
        ...List.generate(
          value.columnsBioChemical.length + 1,
          (index) => index == 0
              ? _tableCell(
                  '생물·화학적 손상',
                  bold: true,
                  textColor: Colors.white,
                  fontSize: isCompact ? 11 : 14,
                )
              : _tableCell('', fontSize: isCompact ? 11 : 14),
        ),
        _tableCell(
          '손상등급',
          bold: true,
          textColor: Colors.white,
          fontSize: isCompact ? 11 : 14,
        ),
      ],
    );
  }

  TableRow _buildSubHeaderRow(bool isCompact) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFE5E5E5)),
      children: [
        _tableCell('', fontSize: isCompact ? 11 : 13),
        _tableCell('', fontSize: isCompact ? 11 : 13),
        ...value.columnsStructural.map(
          (col) => _tableCell(col, bold: true, fontSize: isCompact ? 11 : 13),
        ),
        _tableCell('', fontSize: isCompact ? 11 : 13),
        ...value.columnsPhysical.map(
          (col) => _tableCell(col, bold: true, fontSize: isCompact ? 11 : 13),
        ),
        _tableCell('', fontSize: isCompact ? 11 : 13),
        ...value.columnsBioChemical.map(
          (col) => _tableCell(col, bold: true, fontSize: isCompact ? 11 : 13),
        ),
        _tableCell('', fontSize: isCompact ? 11 : 13),
      ],
    );
  }

  TableRow _buildDataRow(DamageRow row, bool isCompact) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFE5E5E5)),
      children: [
        _tableCell(
          row.label.isEmpty ? '입력 필요' : row.label,
          fontSize: isCompact ? 11 : 13,
        ),
        _tableCell('', fontSize: isCompact ? 11 : 13),
        ...value.columnsStructural.map((col) {
          final cell = row.structural[col] ?? const DamageCell();
          final display = _formatPositionData(cell);
          return _tableCell(display, fontSize: isCompact ? 11 : 13);
        }),
        _tableCell('', fontSize: isCompact ? 11 : 13),
        ...value.columnsPhysical.map((col) {
          final cell = row.physical[col] ?? const DamageCell();
          final display = _formatPositionData(cell);
          return _tableCell(display, fontSize: isCompact ? 11 : 13);
        }),
        _tableCell('', fontSize: isCompact ? 11 : 13),
        ...value.columnsBioChemical.map((col) {
          final cell = row.bioChemical[col] ?? const DamageCell();
          final display = _formatPositionData(cell);
          return _tableCell(display, fontSize: isCompact ? 11 : 13);
        }),
        _buildGradeSummary(row, isCompact),
      ],
    );
  }

  Widget _buildGradeSummary(DamageRow row, bool isCompact) {
    return Container(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gradeBadge('육안', row.visualGrade, Colors.green, isCompact),
          const SizedBox(height: 2),
          _gradeBadge('실험실', row.labGrade, Colors.orange, isCompact),
          const SizedBox(height: 2),
          _gradeBadge('최종', row.finalGrade, Colors.indigo, isCompact),
        ],
      ),
    );
  }

  Widget _gradeBadge(
    String label,
    String grade,
    MaterialColor color,
    bool isCompact,
  ) {
    final display = grade.isEmpty ? '-' : grade;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: isCompact ? 4 : 8),
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color.shade700,
            ),
          ),
          Text(
            display,
            style: TextStyle(
              fontSize: isCompact ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPositionData(DamageCell cell) {
    if (!cell.present) {
      return 'X/X/X';
    }

    String normalize(String input) {
      if (input == '-') return '-';
      return input == 'O' ? 'O' : 'X';
    }

    final left = normalize(cell.positionLeft);
    final center = normalize(cell.positionCenter);
    final right = normalize(cell.positionRight);
    return '$left/$center/$right';
  }

  Widget _tableCell(
    String text, {
    bool bold = false,
    Color? textColor,
    double? fontSize,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize ?? 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: textColor ?? Colors.black87,
          ),
        ),
      ),
    );
  }
}
