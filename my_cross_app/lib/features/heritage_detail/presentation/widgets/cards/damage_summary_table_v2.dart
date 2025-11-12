import 'package:flutter/material.dart';
import 'package:my_cross_app/models/heritage_detail_models.dart';

/// 손상등급 정보 (육안/심화 각각 3개 등급)
class DamageGradeInfo {
  const DamageGradeInfo({
    this.visualGrades = const ['-', '-', '-'], // 육안 등급 3개
    this.inDepthGrades = const ['-', '-', '-'], // 심화 등급 3개
  });

  final List<String> visualGrades; // 육안 등급 (녹색)
  final List<String> inDepthGrades; // 심화 등급 (주황색)

  DamageGradeInfo copyWith({
    List<String>? visualGrades,
    List<String>? inDepthGrades,
  }) {
    return DamageGradeInfo(
      visualGrades: visualGrades ?? this.visualGrades,
      inDepthGrades: inDepthGrades ?? this.inDepthGrades,
    );
  }
}

/// 손상부 종합 테이블 (UI 시안 기반)
/// 이미지 요구사항에 맞게 구현된 버전
class DamageSummaryTableV2 extends StatelessWidget {
  const DamageSummaryTableV2({
    super.key,
    required this.value,
    required this.onChanged,
    this.gradeInfoMap,
  });

  final DamageSummary value;
  final ValueChanged<DamageSummary> onChanged;
  // 각 행별 손상등급 정보 (기본값: 모의 데이터)
  final Map<int, DamageGradeInfo>? gradeInfoMap;

  // 모의 데이터 (이미지 예시 기반)
  // 기둥 02번 (서): 육안 A C C / 심화 B B D
  // 기둥 18번 (남): 육안 B D C / 심화 -
  static Map<int, DamageGradeInfo> get _mockGradeData => {
        0: const DamageGradeInfo(
          visualGrades: ['A', 'C', 'C'],
          inDepthGrades: ['B', 'B', 'D'],
        ),
        1: const DamageGradeInfo(
          visualGrades: ['B', 'D', 'C'],
          inDepthGrades: ['-', '-', '-'],
        ),
      };

  // 모의 손상 데이터 (이미지 예시 기반)
  // 기둥 02번 (서): 이격/이완 O/X/O, 기울 O/O/O, 탈락 X/O/X, 갈램 X/O/O, 천공 X/O/X, 부후 X/O/O
  // 기둥 18번 (남): 이격/이완 X/O/X, 기울 O/O/X, 탈락 X/X/X, 갈램 O/O/O, 천공 X/X/O, 부후 X/O/O
  static DamageSummary get _mockDamageSummary {
    final summary = DamageSummary.initial();
    final rows = <DamageRow>[];

    // 기둥 02번 (서)
    rows.add(
      DamageRow(
        label: '기둥 02번 (서)',
        structural: {
          '이격/이완': const DamageCell(
            present: true,
            positionTop: 'O',
            positionMiddle: 'X',
            positionBottom: 'O',
          ),
          '기울': const DamageCell(
            present: true,
            positionTop: 'O',
            positionMiddle: 'O',
            positionBottom: 'O',
          ),
        },
        physical: {
          '탈락': const DamageCell(
            present: true,
            positionTop: 'X',
            positionMiddle: 'O',
            positionBottom: 'X',
          ),
          '갈램': const DamageCell(
            present: true,
            positionTop: 'X',
            positionMiddle: 'O',
            positionBottom: 'O',
          ),
        },
        bioChemical: {
          '천공': const DamageCell(
            present: true,
            positionTop: 'X',
            positionMiddle: 'O',
            positionBottom: 'X',
          ),
          '부후': const DamageCell(
            present: true,
            positionTop: 'X',
            positionMiddle: 'O',
            positionBottom: 'O',
          ),
        },
        visualGrade: 'A',
        labGrade: 'B',
        finalGrade: 'C',
      ),
    );

    // 기둥 18번 (남)
    rows.add(
      DamageRow(
        label: '기둥 18번 (남)',
        structural: {
          '이격/이완': const DamageCell(
            present: true,
            positionTop: 'X',
            positionMiddle: 'O',
            positionBottom: 'X',
          ),
          '기울': const DamageCell(
            present: true,
            positionTop: 'O',
            positionMiddle: 'O',
            positionBottom: 'X',
          ),
        },
        physical: {
          '탈락': const DamageCell(
            present: false,
            positionTop: 'X',
            positionMiddle: 'X',
            positionBottom: 'X',
          ),
          '갈램': const DamageCell(
            present: true,
            positionTop: 'O',
            positionMiddle: 'O',
            positionBottom: 'O',
          ),
        },
        bioChemical: {
          '천공': const DamageCell(
            present: true,
            positionTop: 'X',
            positionMiddle: 'X',
            positionBottom: 'O',
          ),
          '부후': const DamageCell(
            present: true,
            positionTop: 'X',
            positionMiddle: 'O',
            positionBottom: 'O',
          ),
        },
        visualGrade: 'B',
        labGrade: '',
        finalGrade: 'C',
      ),
    );

    return summary.copyWith(rows: rows);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    // 모의 데이터가 없으면 모의 데이터 사용 (개발/테스트용)
    final displayValue = value.rows.isEmpty ? _mockDamageSummary : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 검은색 헤더 바
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
        // 빨간색 주석
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            '* 손상이 탐지된 경우 O / 아닌 경우 X 로 표기',
            style: TextStyle(
              color: Colors.red,
              fontSize: isMobile ? 11 : 12,
            ),
          ),
        ),
        // 가로 스크롤 가능한 테이블
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildTable(displayValue, isMobile),
        ),
      ],
    );
  }

  Widget _buildTable(DamageSummary displayValue, bool isMobile) {
    return Table(
      border: TableBorder.all(
        color: Colors.black26,
        width: 1,
      ),
      defaultColumnWidth: isMobile
          ? const FixedColumnWidth(80)
          : const FixedColumnWidth(100),
      children: [
        // 그룹 헤더 행 (상단)
        _buildHeaderRow(displayValue, isMobile),
        // 서브 헤더 행 (하단 - 실제 컬럼명)
        _buildSubHeaderRow(displayValue, isMobile),
        // 데이터 행들
        ...displayValue.rows.asMap().entries.map(
              (entry) => _buildDataRow(displayValue, entry.value, entry.key, isMobile),
            ),
      ],
    );
  }

  TableRow _buildHeaderRow(DamageSummary displayValue, bool isMobile) {
    return TableRow(
      decoration: const BoxDecoration(
        color: Color(0xFF333333), // dark gray
      ),
      children: [
        _tableCell(
          '손상 유형',
          bold: true,
          textColor: Colors.white,
          fontSize: isMobile ? 11 : 14,
        ),
        // 구조적 손상 그룹 (서브 컬럼 수만큼 병합)
        ...List.generate(
          displayValue.columnsStructural.length + 1,
          (index) => index == 0
              ? _tableCell(
                  '구조적 손상',
                  bold: true,
                  textColor: Colors.white,
                  fontSize: isMobile ? 11 : 14,
                )
              : _tableCell('', fontSize: isMobile ? 11 : 14),
        ),
        // 물리적 손상 그룹
        ...List.generate(
          displayValue.columnsPhysical.length + 1,
          (index) => index == 0
              ? _tableCell(
                  '물리적 손상',
                  bold: true,
                  textColor: Colors.white,
                  fontSize: isMobile ? 11 : 14,
                )
              : _tableCell('', fontSize: isMobile ? 11 : 14),
        ),
        // 생물·화학적 손상 그룹
        ...List.generate(
          displayValue.columnsBioChemical.length + 1,
          (index) => index == 0
              ? _tableCell(
                  '생물·화학적 손상',
                  bold: true,
                  textColor: Colors.white,
                  fontSize: isMobile ? 11 : 14,
                )
              : _tableCell('', fontSize: isMobile ? 11 : 14),
        ),
        // 손상등급 헤더
        _tableCell(
          '손상등급',
          bold: true,
          textColor: Colors.white,
          fontSize: isMobile ? 11 : 14,
        ),
      ],
    );
  }

  TableRow _buildSubHeaderRow(DamageSummary displayValue, bool isMobile) {
    return TableRow(
      decoration: const BoxDecoration(
        color: Color(0xFFE5E5E5), // light gray
      ),
      children: [
        _tableCell(
          '', // 손상 유형 아래는 빈 셀
          fontSize: isMobile ? 11 : 13,
        ),
        // 구조적 손상 서브 헤더
        _tableCell('', fontSize: isMobile ? 11 : 13), // 그룹 헤더 아래 빈 셀
        ...displayValue.columnsStructural.map((col) => _tableCell(
              col,
              bold: true,
              fontSize: isMobile ? 11 : 13,
            )),
        // 물리적 손상 서브 헤더
        _tableCell('', fontSize: isMobile ? 11 : 13), // 그룹 헤더 아래 빈 셀
        ...displayValue.columnsPhysical.map((col) => _tableCell(
              col,
              bold: true,
              fontSize: isMobile ? 11 : 13,
            )),
        // 생물·화학적 손상 서브 헤더
        _tableCell('', fontSize: isMobile ? 11 : 13), // 그룹 헤더 아래 빈 셀
        ...displayValue.columnsBioChemical.map((col) => _tableCell(
              col,
              bold: true,
              fontSize: isMobile ? 11 : 13,
            )),
        // 손상등급 서브 헤더 (빈 셀)
        _tableCell('', fontSize: isMobile ? 11 : 13),
      ],
    );
  }

  TableRow _buildDataRow(
    DamageSummary displayValue,
    DamageRow row,
    int rowIndex,
    bool isMobile,
  ) {
    final gradeInfo = gradeInfoMap?[rowIndex] ??
        _mockGradeData[rowIndex] ??
        const DamageGradeInfo();

    return TableRow(
      decoration: const BoxDecoration(
        color: Color(0xFFE5E5E5), // light gray
      ),
      children: [
        // 손상 유형
        _tableCell(
          row.label.isEmpty ? '입력 필요' : row.label,
          fontSize: isMobile ? 11 : 13,
        ),
        // 구조적 손상 그룹 헤더 (빈 셀)
        _tableCell('', fontSize: isMobile ? 11 : 13),
        // 구조적 손상 데이터 (O/X/O 형식)
        ...displayValue.columnsStructural.map((col) {
          final cell = row.structural[col] ?? const DamageCell();
          final display = _formatPositionData(cell);
          return _tableCell(
            display,
            fontSize: isMobile ? 11 : 13,
          );
        }),
        // 물리적 손상 그룹 헤더 (빈 셀)
        _tableCell('', fontSize: isMobile ? 11 : 13),
        // 물리적 손상 데이터 (O/X/O 형식)
        ...displayValue.columnsPhysical.map((col) {
          final cell = row.physical[col] ?? const DamageCell();
          final display = _formatPositionData(cell);
          return _tableCell(
            display,
            fontSize: isMobile ? 11 : 13,
          );
        }),
        // 생물·화학적 손상 그룹 헤더 (빈 셀)
        _tableCell('', fontSize: isMobile ? 11 : 13),
        // 생물·화학적 손상 데이터 (O/X/O 형식)
        ...displayValue.columnsBioChemical.map((col) {
          final cell = row.bioChemical[col] ?? const DamageCell();
          final display = _formatPositionData(cell);
          return _tableCell(
            display,
            fontSize: isMobile ? 11 : 13,
          );
        }),
        // 손상등급 서브테이블
        _buildGradeSubTable(gradeInfo, isMobile),
      ],
    );
  }

  /// O/X/O 형식으로 포맷팅 (상/중/하)
  String _formatPositionData(DamageCell cell) {
    if (!cell.present) {
      return 'X/X/X';
    }
    final top = cell.positionTop == 'O' ? 'O' : 'X';
    final middle = cell.positionMiddle == 'O' ? 'O' : 'X';
    final bottom = cell.positionBottom == 'O' ? 'O' : 'X';
    return '$top/$middle/$bottom';
  }

  /// 손상등급 서브테이블 (육안/심화)
  Widget _buildGradeSubTable(DamageGradeInfo gradeInfo, bool isMobile) {
    if (isMobile) {
      // 모바일: 세로로 스택
      return Container(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(
                '육안: ${gradeInfo.visualGrades.join(' ')}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                '심화: ${gradeInfo.inDepthGrades.join(' ')}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 100.0;
        final count = gradeInfo.visualGrades.length.clamp(1, 4);
        final spacing = 4.0;
        final rawWidth = (width - (spacing * (count - 1))) / count;
        final cellWidth = rawWidth.isFinite
            ? rawWidth.clamp(18.0, width)
            : width;

        Widget buildRow(List<String> grades, Color tone) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: grades
                .map(
                  (grade) => SizedBox(
                    width: cellWidth,
                    child: _gradeCell(
                      grade,
                      tone,
                      compact: cellWidth < 28,
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Container(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildRow(gradeInfo.visualGrades, Colors.green),
              const SizedBox(height: 2),
              buildRow(gradeInfo.inDepthGrades, Colors.orange),
            ],
          ),
        );
      },
    );
  }

  Widget _gradeCell(
    String grade,
    Color bgColor, {
    bool compact = false,
  }) {
    // Color에서 shade를 얻기 위해 MaterialColor로 변환하거나 직접 색상 계산
    final lightColor = Color.lerp(bgColor, Colors.white, 0.9) ?? bgColor;
    final borderColor = Color.lerp(bgColor, Colors.black, 0.3) ?? bgColor;
    final textColor = Color.lerp(bgColor, Colors.black, 0.8) ?? Colors.black;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: EdgeInsets.symmetric(
        vertical: 4,
        horizontal: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: lightColor,
        border: Border.all(color: borderColor),
      ),
      child: Text(
        grade,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
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

