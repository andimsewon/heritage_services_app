import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'damage_assessment_models.dart';
import 'damage_grade_calculator.dart';

/// 통합 손상부 종합 테이블 (O/X + 등급 통합)
class UnifiedDamageTable extends StatefulWidget {
  const UnifiedDamageTable({
    super.key,
    required this.components,
    required this.grades,
    required this.onCellChanged,
    required this.onGradeChanged,
    this.autoGradeEnabled = true,
    this.isReadOnly = false,
  });

  final List<ComponentOxData> components;
  final Map<String, ComponentGradeData> grades;
  final void Function(String componentId, String columnId, String value)
      onCellChanged;
  final void Function(String componentId, String type, String grade)?
      onGradeChanged;
  final bool autoGradeEnabled;
  final bool isReadOnly;

  @override
  State<UnifiedDamageTable> createState() => _UnifiedDamageTableState();
}

class _UnifiedDamageTableState extends State<UnifiedDamageTable> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // 컬럼 정의
  static const List<String> _structuralColumns = [
    '이격/이완',
    '기울',
    '기타 구조항목',
  ];
  static const List<String> _physicalColumns = [
    '탈락',
    '갈램',
    '기타 물리항목',
  ];
  static const List<String> _biochemicalColumns = [
    '천공',
    '부후',
    '기타 생화학항목',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (final component in widget.components) {
      for (final column in _getAllColumns()) {
        final key = '${component.componentId}_$column';
        final value = component.oxValues[column] ?? '';
        _controllers[key] = TextEditingController(text: value);
        _focusNodes[key] = FocusNode();
      }
    }
  }

  @override
  void didUpdateWidget(UnifiedDamageTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 컴포넌트 개수나 ID 목록이 변경되었는지 확인
    final oldIds = oldWidget.components.map((c) => c.componentId).toSet();
    final newIds = widget.components.map((c) => c.componentId).toSet();
    
    if (oldIds.length != newIds.length || 
        !oldIds.containsAll(newIds) || 
        !newIds.containsAll(oldIds)) {
      // 새로운 컴포넌트가 추가되었거나 삭제된 경우
      // 기존 컨트롤러는 유지하고, 새로운 컴포넌트만 추가
      for (final component in widget.components) {
        if (!oldIds.contains(component.componentId)) {
          // 새로운 컴포넌트 - 컨트롤러 추가
          for (final column in _getAllColumns()) {
            final key = '${component.componentId}_$column';
            if (!_controllers.containsKey(key)) {
              final value = component.oxValues[column] ?? '';
              _controllers[key] = TextEditingController(text: value);
              _focusNodes[key] = FocusNode();
            }
          }
        }
      }
      
      // 삭제된 컴포넌트의 컨트롤러 정리
      final toRemove = <String>[];
      for (final key in _controllers.keys) {
        final componentId = key.split('_').first;
        if (!newIds.contains(componentId)) {
          toRemove.add(key);
        }
      }
      for (final key in toRemove) {
        _controllers[key]?.dispose();
        _focusNodes[key]?.dispose();
        _controllers.remove(key);
        _focusNodes.remove(key);
      }
      
      // 기존 컴포넌트의 값 업데이트
      for (final component in widget.components) {
        if (oldIds.contains(component.componentId)) {
          for (final column in _getAllColumns()) {
            final key = '${component.componentId}_$column';
            final controller = _controllers[key];
            if (controller != null) {
              final newValue = component.oxValues[column] ?? '';
              if (controller.text != newValue) {
                controller.text = newValue;
              }
            }
          }
        }
      }
    }
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  List<String> _getAllColumns() {
    return [
      ..._structuralColumns,
      ..._physicalColumns,
      ..._biochemicalColumns,
    ];
  }

  void _onCellChanged(String componentId, String columnId, String value) {
    if (!DamageGradeCalculator.isValidOxValue(value)) {
      return;
    }
    final normalized = DamageGradeCalculator.normalizeOxValue(value);
    widget.onCellChanged(componentId, columnId, normalized);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isNarrow) {
          // 매우 좁은 화면: 세로 스택
          return _buildVerticalLayout(constraints.maxWidth);
        } else if (isMobile) {
          // 모바일: 가로 스크롤 가능한 통합 테이블
          return _buildHorizontalScrollableTable(constraints.maxWidth);
        } else {
          // 데스크톱: 통합 테이블
          return _buildHorizontalScrollableTable(constraints.maxWidth);
        }
      },
    );
  }

  /// 세로 스택 레이아웃 (매우 좁은 화면)
  Widget _buildVerticalLayout(double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 구조적 손상
        _buildDamageGroupCard(
          '구조적 손상',
          _structuralColumns,
          Colors.blue,
          maxWidth,
        ),
        const SizedBox(height: 16),
        // 물리적 손상
        _buildDamageGroupCard(
          '물리적 손상',
          _physicalColumns,
          Colors.orange,
          maxWidth,
        ),
        const SizedBox(height: 16),
        // 생물·화학적 손상
        _buildDamageGroupCard(
          '생물·화학적 손상',
          _biochemicalColumns,
          Colors.green,
          maxWidth,
        ),
        const SizedBox(height: 16),
        // 손상등급 테이블
        _buildGradeTableVertical(maxWidth),
      ],
    );
  }

  /// 손상 그룹 카드 (세로 레이아웃용)
  Widget _buildDamageGroupCard(
    String title,
    List<String> columns,
    Color groupColor,
    double maxWidth,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: groupColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: groupColor,
              ),
            ),
          ),
          // 테이블
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: maxWidth),
              child: _buildGroupTable(columns, groupColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 그룹별 테이블 (세로 레이아웃용)
  Widget _buildGroupTable(List<String> columns, Color groupColor) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: {
        0: const FixedColumnWidth(120),
        for (int i = 0; i < columns.length; i++) i + 1: const FixedColumnWidth(100),
      },
      children: [
        // 헤더 행
        TableRow(
          decoration: BoxDecoration(
            color: const Color(0xFFE5E5E5),
          ),
          children: [
            _buildTableCell('구성 요소', isHeader: true),
            ...columns.map((col) => _buildTableCell(col, isHeader: true)),
          ],
        ),
        // 데이터 행
        ...widget.components.map((component) {
          return TableRow(
            decoration: const BoxDecoration(color: Colors.white),
            children: [
              _buildTableCell(component.componentName),
              ...columns.map((column) {
                return _buildEditableCell(
                  component.componentId,
                  column,
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  /// 가로 스크롤 가능한 통합 테이블
  Widget _buildHorizontalScrollableTable(double maxWidth) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 고정 헤더
          _buildFixedHeader(maxWidth),
          // 스크롤 가능한 본문
          Flexible(
            child: Scrollbar(
              controller: _verticalScrollController,
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: _buildUnifiedTable(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 고정 헤더 (완전히 고정, 스크롤 없음)
  Widget _buildFixedHeader(double maxWidth) {
    // 헤더의 최소 너비 계산
    final minHeaderWidth = 120.0 +
        (_structuralColumns.length * 100.0) +
        (_physicalColumns.length * 100.0) +
        (_biochemicalColumns.length * 100.0) +
        120.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: OverflowBox(
        maxWidth: double.infinity,
        minWidth: minHeaderWidth,
        child: Row(
          children: [
            _buildHeaderCell('손상 유형', width: 120),
            _buildGroupHeader('구조적 손상', _structuralColumns),
            _buildGroupHeader('물리적 손상', _physicalColumns),
            _buildGroupHeader('생물·화학적 손상', _biochemicalColumns),
            _buildHeaderCell('손상등급', width: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, List<String> columns) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          _buildHeaderCell(title, width: columns.length * 100.0),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5E5),
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell('', width: 0, isSubHeader: true),
                ...columns.map((col) => _buildHeaderCell(
                      col,
                      width: 100,
                      isSubHeader: true,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String text, {
    required double width,
    bool isSubHeader = false,
  }) {
    return Container(
      width: width > 0 ? width : null,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSubHeader ? 12 : 14,
            fontWeight: isSubHeader ? FontWeight.w600 : FontWeight.bold,
            color: isSubHeader ? Colors.black87 : Colors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// 통합 테이블 (O/X + 등급)
  Widget _buildUnifiedTable() {
    final minTableWidth = 120.0 +
        (_structuralColumns.length * 100.0) +
        (_physicalColumns.length * 100.0) +
        (_biochemicalColumns.length * 100.0) +
        120.0; // 손상등급 컬럼

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minTableWidth),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300),
        columnWidths: {
          0: const FixedColumnWidth(120), // 손상 유형
          for (int i = 1; i <= _getAllColumns().length; i++)
            i: const FixedColumnWidth(100),
          _getAllColumns().length + 1: const FixedColumnWidth(120), // 손상등급
        },
        children: [
          ...widget.components.map((component) => _buildUnifiedDataRow(component)),
        ],
      ),
    );
  }

  TableRow _buildUnifiedDataRow(ComponentOxData component) {
    final gradeData = widget.grades[component.componentId] ??
        ComponentGradeData(componentId: component.componentId);

    return TableRow(
      decoration: const BoxDecoration(color: Colors.white),
      children: [
        // 손상 유형 (구성 요소 이름)
        _buildTableCell(component.componentName),
        // 구조적 손상
        _buildTableCell(''), // 그룹 헤더 빈 셀
        ..._structuralColumns.map((col) => _buildEditableCell(
              component.componentId,
              col,
            )),
        // 물리적 손상
        _buildTableCell(''), // 그룹 헤더 빈 셀
        ..._physicalColumns.map((col) => _buildEditableCell(
              component.componentId,
              col,
            )),
        // 생물·화학적 손상
        _buildTableCell(''), // 그룹 헤더 빈 셀
        ..._biochemicalColumns.map((col) => _buildEditableCell(
              component.componentId,
              col,
            )),
        // 손상등급 (육안/심화)
        _buildGradeCell(gradeData),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isHeader ? const Color(0xFFE5E5E5) : Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEditableCell(String componentId, String columnId) {
    final key = '${componentId}_$columnId';
    final controller = _controllers[key] ?? TextEditingController();
    final focusNode = _focusNodes[key] ?? FocusNode();
    final value = controller.text;
    final isValid = _isValid(value);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
        color: isValid ? Colors.white : Colors.red.shade50,
      ),
      child: widget.isReadOnly
          ? Center(
              child: Text(
                value.isEmpty ? '-' : value,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          : TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[OX/\s]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = newValue.text.toUpperCase();
                  return TextEditingValue(
                    text: text,
                    selection: newValue.selection,
                  );
                }),
              ],
              onChanged: (value) {
                _onCellChanged(componentId, columnId, value);
              },
              onSubmitted: (value) {
                final normalized = DamageGradeCalculator.normalizeOxValue(value);
                controller.text = normalized;
                _onCellChanged(componentId, columnId, normalized);
              },
            ),
    );
  }

  bool _isValid(String value) {
    if (value.isEmpty) return true;
    return DamageGradeCalculator.isValidOxValue(value);
  }

  /// 손상등급 셀 (육안/심화)
  Widget _buildGradeCell(ComponentGradeData gradeData) {
    final visualGrade = gradeData.visualGrade;
    final advancedGrade = gradeData.advancedGrade;
    final isEditable = !widget.autoGradeEnabled &&
        widget.onGradeChanged != null &&
        gradeData.isManualOverride;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 육안 등급 (녹색)
          _buildGradeBadge(
            visualGrade,
            'visual',
            gradeData.componentId,
            Colors.green,
            isEditable,
          ),
          const SizedBox(height: 4),
          // 심화 등급 (주황)
          _buildGradeBadge(
            advancedGrade,
            'advanced',
            gradeData.componentId,
            Colors.orange,
            isEditable,
          ),
        ],
      ),
    );
  }

  Widget _buildGradeBadge(
    String grade,
    String type,
    String componentId,
    Color color,
    bool isEditable,
  ) {
    final gradeColor = _getGradeColor(grade);
    final bgColor = color.withOpacity(0.1);
    final borderColor = color.withOpacity(0.5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: isEditable && widget.onGradeChanged != null
          ? DropdownButton<String>(
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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getGradeColor(g),
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (newGrade) {
                if (newGrade != null && widget.onGradeChanged != null) {
                  widget.onGradeChanged!(componentId, type, newGrade);
                }
              },
            )
          : Center(
              child: Text(
                grade,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: gradeColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF4CAF50);
      case 'B':
        return const Color(0xFF8BC34A);
      case 'C':
        return const Color(0xFFFFC107);
      case 'D':
        return const Color(0xFFFF5722);
      default:
        return Colors.grey;
    }
  }

  /// 세로 레이아웃용 등급 테이블
  Widget _buildGradeTableVertical(double maxWidth) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Text(
              '손상등급',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: {
              0: const FixedColumnWidth(120),
              1: const FixedColumnWidth(80),
              2: const FixedColumnWidth(80),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E5E5),
                ),
                children: [
                  _buildTableCell('구성 요소', isHeader: true),
                  _buildTableCell('육안', isHeader: true),
                  _buildTableCell('심화', isHeader: true),
                ],
              ),
              ...widget.components.map((component) {
                final gradeData = widget.grades[component.componentId] ??
                    ComponentGradeData(componentId: component.componentId);
                return TableRow(
                  decoration: const BoxDecoration(color: Colors.white),
                  children: [
                    _buildTableCell(component.componentName),
                    _buildGradeBadge(
                      gradeData.visualGrade,
                      'visual',
                      component.componentId,
                      Colors.green,
                      !widget.autoGradeEnabled &&
                          widget.onGradeChanged != null &&
                          gradeData.isManualOverride,
                    ),
                    _buildGradeBadge(
                      gradeData.advancedGrade,
                      'advanced',
                      component.componentId,
                      Colors.orange,
                      !widget.autoGradeEnabled &&
                          widget.onGradeChanged != null &&
                          gradeData.isManualOverride,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

