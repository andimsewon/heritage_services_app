import 'package:flutter/material.dart';
import 'damage_assessment_models.dart';

/// 손상 등급 테이블 (육안/심화)
class DamageGradeTable extends StatelessWidget {
  const DamageGradeTable({
    super.key,
    required this.components,
    required this.grades,
    this.onGradeChanged,
    this.autoGradeEnabled = true,
  });

  final List<ComponentOxData> components;
  final Map<String, ComponentGradeData> grades;
  final void Function(String componentId, String type, String grade)?
      onGradeChanged;
  final bool autoGradeEnabled;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight.isFinite 
                ? constraints.maxHeight 
                : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              _buildHeader(isMobile),
              // 본문
              Flexible(
                child: SingleChildScrollView(
                  child: _buildTable(isMobile),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('구성 요소', width: 120, isMobile: isMobile),
          _buildHeaderCell('육안', width: 80, isMobile: isMobile),
          _buildHeaderCell('심화', width: 80, isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required double width, required bool isMobile}) {
    return Container(
      width: width,
      padding: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: isMobile ? 11 : 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTable(bool isMobile) {
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
        verticalInside: BorderSide(color: Colors.grey.shade300),
      ),
      columnWidths: {
        0: FixedColumnWidth(120.0),
        1: FixedColumnWidth(80.0),
        2: FixedColumnWidth(80.0),
      },
      children: [
        for (final component in components)
          _buildDataRow(component, isMobile),
      ],
    );
  }

  TableRow _buildDataRow(ComponentOxData component, bool isMobile) {
    final gradeData = grades[component.componentId] ??
        ComponentGradeData(componentId: component.componentId);
    
    final visualGrade = gradeData.visualGrade;
    final advancedGrade = gradeData.advancedGrade;
    final isManual = gradeData.isManualOverride;

    return TableRow(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      children: [
        // 구성 요소 이름
        _buildLabelCell(component.componentName, isMobile),
        // 육안 등급
        _buildGradeCell(
          visualGrade,
          'visual',
          component.componentId,
          Colors.green,
          isMobile,
          isManual && !autoGradeEnabled,
        ),
        // 심화 등급
        _buildGradeCell(
          advancedGrade,
          'advanced',
          component.componentId,
          Colors.orange,
          isMobile,
          isManual && !autoGradeEnabled,
        ),
      ],
    );
  }

  Widget _buildLabelCell(String label, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildGradeCell(
    String grade,
    String type,
    String componentId,
    Color color,
    bool isMobile,
    bool isEditable,
  ) {
    final gradeColor = _getGradeColor(grade);
    final bgColor = gradeColor.withOpacity(0.1);
    final borderColor = gradeColor.withOpacity(0.5);

    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          top: BorderSide(color: borderColor, width: 2),
          bottom: BorderSide(color: borderColor, width: 2),
          left: BorderSide(color: borderColor, width: 2),
        ),
      ),
      child: isEditable && onGradeChanged != null
          ? _buildEditableGradeCell(
              grade,
              type,
              componentId,
              gradeColor,
              isMobile,
            )
          : Center(
              child: Text(
                grade,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  color: gradeColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  Widget _buildEditableGradeCell(
    String grade,
    String type,
    String componentId,
    Color color,
    bool isMobile,
  ) {
    return DropdownButton<String>(
      value: grade,
      isExpanded: true,
      underline: Container(),
      items: ['A', 'B', 'C', 'D'].map((g) {
        return DropdownMenuItem(
          value: g,
          child: Center(
            child: Text(
              g,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.bold,
                color: _getGradeColor(g),
              ),
            ),
          ),
        );
      }).toList(),
      onChanged: (newGrade) {
        if (newGrade != null && onGradeChanged != null) {
          onGradeChanged!(componentId, type, newGrade);
        }
      },
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF4CAF50); // Green
      case 'B':
        return const Color(0xFF8BC34A); // Light Green
      case 'C':
        return const Color(0xFFFFC107); // Amber
      case 'D':
        return const Color(0xFFFF5722); // Deep Orange
      default:
        return Colors.grey;
    }
  }
}

