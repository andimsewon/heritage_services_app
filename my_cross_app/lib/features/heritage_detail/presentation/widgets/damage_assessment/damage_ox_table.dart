import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'damage_assessment_models.dart';
import 'damage_grade_calculator.dart';

/// O/X 편집 가능한 손상표 테이블
class DamageOxTable extends StatefulWidget {
  const DamageOxTable({
    super.key,
    required this.components,
    required this.columns,
    required this.onCellChanged,
    this.isReadOnly = false,
  });

  final List<ComponentOxData> components;
  final List<String> columns;
  final void Function(String componentId, String columnId, String value)
      onCellChanged;
  final bool isReadOnly;

  @override
  State<DamageOxTable> createState() => _DamageOxTableState();
}

class _DamageOxTableState extends State<DamageOxTable> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (final component in widget.components) {
      for (final column in widget.columns) {
        final key = '${component.componentId}_$column';
        final value = component.oxValues[column] ?? '';
        
        _controllers[key] = TextEditingController(text: value);
        _focusNodes[key] = FocusNode();
      }
    }
  }

  @override
  void didUpdateWidget(DamageOxTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.components != widget.components ||
        oldWidget.columns != widget.columns) {
      _disposeControllers();
      _initializeControllers();
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

  void _onCellChanged(String componentId, String columnId, String value) {
    // 입력 검증
    if (!DamageGradeCalculator.isValidOxValue(value)) {
      // 잘못된 입력 - 빨간색 표시 (나중에 구현)
      return;
    }

    // 정규화
    final normalized = DamageGradeCalculator.normalizeOxValue(value);
    
    // 콜백 호출
    widget.onCellChanged(componentId, columnId, normalized);
  }

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
              // 고정 헤더 (가로 스크롤 동기화)
              _buildHeader(isMobile, constraints.maxWidth),
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
                        child: _buildTable(isMobile),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile, double maxWidth) {
    // 헤더는 고정, 본문의 스크롤과 동기화되도록 Listener 사용
    return Listener(
      onPointerSignal: (event) {
        // 스크롤 이벤트는 본문에서 처리
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: OverflowBox(
          maxWidth: double.infinity,
          child: Row(
            children: [
              // 구성 요소 컬럼
              _buildHeaderCell('구성 요소', width: 120, isMobile: isMobile),
              // 그룹별 헤더
              _buildGroupHeader('구조적 손상', _getStructuralColumns(), isMobile),
              _buildGroupHeader('물리적 손상', _getPhysicalColumns(), isMobile),
              _buildGroupHeader(
                '생물·화학적 손상',
                _getBiochemicalColumns(),
                isMobile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, List<String> columns, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          // 그룹 헤더
          _buildHeaderCell(title, width: columns.length * 100.0, isMobile: isMobile),
          // 서브 헤더
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5E5),
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                for (final column in columns)
                  _buildHeaderCell(
                    column,
                    width: 100,
                    isMobile: isMobile,
                    isSubHeader: true,
                  ),
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
    required bool isMobile,
    bool isSubHeader = false,
  }) {
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
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 11 : (isSubHeader ? 12 : 14),
            fontWeight: isSubHeader ? FontWeight.w600 : FontWeight.bold,
            color: isSubHeader ? Colors.black87 : Colors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTable(bool isMobile) {
    // 테이블의 최소 너비 계산 (헤더와 동일하게)
    final minTableWidth = 120.0 + 
        (_getStructuralColumns().length * 100.0) +
        (_getPhysicalColumns().length * 100.0) +
        (_getBiochemicalColumns().length * 100.0);
    
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minTableWidth,
      ),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.grey.shade300),
          verticalInside: BorderSide(color: Colors.grey.shade300),
        ),
        columnWidths: {
          for (int i = 0; i < widget.columns.length + 1; i++)
            i: FixedColumnWidth(i == 0 ? 120.0 : 100.0),
        },
        children: [
          for (final component in widget.components)
            _buildDataRow(component, isMobile),
        ],
      ),
    );
  }

  TableRow _buildDataRow(ComponentOxData component, bool isMobile) {
    return TableRow(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      children: [
        // 구성 요소 이름
        _buildLabelCell(component.componentName, isMobile),
        // 구조적 손상
        ..._getStructuralColumns().map(
          (column) => _buildEditableCell(
            component.componentId,
            column,
            isMobile,
          ),
        ),
        // 물리적 손상
        ..._getPhysicalColumns().map(
          (column) => _buildEditableCell(
            component.componentId,
            column,
            isMobile,
          ),
        ),
        // 생물·화학적 손상
        ..._getBiochemicalColumns().map(
          (column) => _buildEditableCell(
            component.componentId,
            column,
            isMobile,
          ),
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

  Widget _buildEditableCell(
    String componentId,
    String columnId,
    bool isMobile,
  ) {
    final key = '${componentId}_$columnId';
    final controller = _controllers[key] ?? TextEditingController();
    final focusNode = _focusNodes[key] ?? FocusNode();
    final value = controller.text;

    return Container(
      padding: EdgeInsets.all(isMobile ? 4 : 6),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
        color: _isValid(value) ? Colors.white : Colors.red.shade50,
      ),
      child: widget.isReadOnly
          ? Center(
              child: Text(
                value.isEmpty ? '-' : value,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                errorBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[OX/\s]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  // 자동 대문자 변환
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
                // 정규화된 값으로 업데이트
                final normalized =
                    DamageGradeCalculator.normalizeOxValue(value);
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

  List<String> _getStructuralColumns() {
    return widget.columns
        .where((col) => DamageGradeCalculator.getAllColumns()
            .indexWhere((c) => c == col) < 3)
        .toList();
  }

  List<String> _getPhysicalColumns() {
    final all = DamageGradeCalculator.getAllColumns();
    return widget.columns
        .where((col) {
          final index = all.indexWhere((c) => c == col);
          return index >= 3 && index < 6;
        })
        .toList();
  }

  List<String> _getBiochemicalColumns() {
    final all = DamageGradeCalculator.getAllColumns();
    return widget.columns
        .where((col) {
          final index = all.indexWhere((c) => c == col);
          return index >= 6;
        })
        .toList();
  }
}

