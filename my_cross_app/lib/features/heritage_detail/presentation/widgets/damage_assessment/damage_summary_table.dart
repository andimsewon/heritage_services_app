import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_cross_app/core/services/firebase_service.dart';
import 'damage_grade_calculator.dart';

/// 손상부 종합 테이블 (O/X + 손상등급 통합)
class DamageSummaryTable extends StatefulWidget {
  const DamageSummaryTable({
    super.key,
    required this.heritageId,
    this.sectionNumber,
  });

  final String heritageId;
  final int? sectionNumber;

  @override
  State<DamageSummaryTable> createState() => _DamageSummaryTableState();
}

class _DamageSummaryTableState extends State<DamageSummaryTable> {
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _debounceTimer;
  
  // 데이터
  final Map<String, Map<String, String>> _oxTable = {}; // rowId -> {columnId -> "O/X/O"}
  final Map<String, Map<String, String>> _damageGrades = {}; // rowId -> {visual: "A", advanced: "B"}
  final List<String> _rowIds = []; // 행 순서 유지
  
  // 컨트롤러
  final Map<String, TextEditingController> _oxControllers = {};
  final Map<String, FocusNode> _oxFocusNodes = {};
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _autoGradeEnabled = true;

  // 컬럼 정의 (DamageGradeCalculator에서 가져오기)
  List<String> get _structuralColumns => DamageGradeCalculator.getStructuralColumns();
  List<String> get _physicalColumns => DamageGradeCalculator.getPhysicalColumns();
  List<String> get _biochemicalColumns => DamageGradeCalculator.getBiochemicalColumns();
  List<String> get _allColumns => DamageGradeCalculator.getAllColumns();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _disposeControllers();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in _oxControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _oxFocusNodes.values) {
      focusNode.dispose();
    }
    _oxControllers.clear();
    _oxFocusNodes.clear();
  }

  /// Firestore에서 데이터 로드
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _firebaseService.getDamageAssessmentSummary(
        heritageId: widget.heritageId,
      );

      if (data != null && mounted) {
        final oxTableData = data['oxTable'] as Map<String, dynamic>? ?? {};
        final gradesData = data['damageGrades'] as Map<String, dynamic>? ?? {};
        final autoGrade = data['autoGradeEnabled'] as bool? ?? true;

        setState(() {
          _oxTable.clear();
          _damageGrades.clear();
          _rowIds.clear();

          // O/X 테이블 데이터 로드
          for (final entry in oxTableData.entries) {
            final rowId = entry.key;
            final columns = entry.value as Map<String, dynamic>? ?? {};
            _rowIds.add(rowId);
            _oxTable[rowId] = {};
            for (final colEntry in columns.entries) {
              _oxTable[rowId]![colEntry.key] = colEntry.value.toString();
            }
          }

          // 등급 데이터 로드
          for (final entry in gradesData.entries) {
            final rowId = entry.key;
            final grades = entry.value as Map<String, dynamic>? ?? {};
            _damageGrades[rowId] = {
              'visual': grades['visual']?.toString() ?? 'A',
              'advanced': grades['advanced']?.toString() ?? 'A',
            };
          }

          _autoGradeEnabled = autoGrade;

          // 컨트롤러 초기화
          _initializeControllers();
        });
      } else {
        // 초기 데이터 생성
        if (mounted) {
          _addNewRow();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '데이터 로드 실패: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _initializeControllers() {
    _disposeControllers();
    for (final rowId in _rowIds) {
      for (final column in _allColumns) {
        final key = '${rowId}_$column';
        final value = _oxTable[rowId]?[column] ?? '';
        _oxControllers[key] = TextEditingController(text: value);
        _oxFocusNodes[key] = FocusNode();
      }
    }
  }

  /// 새 행 추가
  void _addNewRow() {
    final newRowId = 'row_${DateTime.now().millisecondsSinceEpoch}';
    
    setState(() {
      _rowIds.add(newRowId);
      _oxTable[newRowId] = {};
      _damageGrades[newRowId] = {
        'visual': 'A',
        'advanced': 'A',
      };
      
      // 컨트롤러 초기화
      for (final column in _allColumns) {
        final key = '${newRowId}_$column';
        _oxControllers[key] = TextEditingController();
        _oxFocusNodes[key] = FocusNode();
      }
    });

    _saveToFirestore();
  }

  /// 행 삭제
  void _removeRow(String rowId) {
    setState(() {
      _rowIds.remove(rowId);
      _oxTable.remove(rowId);
      _damageGrades.remove(rowId);
      
      // 컨트롤러 정리
      for (final column in _allColumns) {
        final key = '${rowId}_$column';
        _oxControllers[key]?.dispose();
        _oxFocusNodes[key]?.dispose();
        _oxControllers.remove(key);
        _oxFocusNodes.remove(key);
      }
    });

    _saveToFirestore();
  }

  /// O/X 값 변경
  void _onOxChanged(String rowId, String columnId, String value) {
    // 입력 검증
    if (!DamageGradeCalculator.isValidOxValue(value)) {
      return;
    }

    final normalized = DamageGradeCalculator.normalizeOxValue(value);

    setState(() {
      _oxTable[rowId] ??= {};
      _oxTable[rowId]![columnId] = normalized;
    });

    // 자동 등급 계산
    if (_autoGradeEnabled) {
      _recalculateGrades(rowId);
    }

    // 디바운싱된 저장
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _saveToFirestore();
    });
  }

  /// 등급 재계산
  void _recalculateGrades(String rowId) {
    final oxValues = _oxTable[rowId] ?? {};
    
    final visualGrade = DamageGradeCalculator.calculateVisualGrade(oxValues);
    final advancedGrade = DamageGradeCalculator.calculateAdvancedGrade(oxValues);

    setState(() {
      _damageGrades[rowId] = {
        'visual': visualGrade,
        'advanced': advancedGrade,
      };
    });

    // 등급 변경 시 즉시 저장
    _saveToFirestore();
  }

  /// 등급 수동 변경
  void _onGradeChanged(String rowId, String type, String grade) {
    setState(() {
      _damageGrades[rowId] ??= {'visual': 'A', 'advanced': 'A'};
      _damageGrades[rowId]![type] = grade;
    });

    _saveToFirestore();
  }

  /// Firestore에 저장
  Future<void> _saveToFirestore() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final data = {
        'oxTable': _oxTable,
        'damageGrades': _damageGrades,
        'autoGradeEnabled': _autoGradeEnabled,
      };

      await _firebaseService.saveDamageAssessmentSummary(
        heritageId: widget.heritageId,
        damageSummary: data,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '저장 실패: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 화면 너비 계산 (LayoutBuilder 제거로 무한대 제약 조건 문제 해결)
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? 16.0 : 24.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : _errorMessage != null
              ? Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
          // 헤더
          _buildHeader(),
          const SizedBox(height: 16),
          // 자동 등급 토글
          _buildAutoGradeToggle(),
          const SizedBox(height: 16),
          // 주석
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '* 손상이 탐지된 경우 O / 아닌 경우 X 로 표기',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 테이블 영역
          if (isMobile)
            // 모바일: 세로 스택
            Column(
              children: [
                _buildOxTable(isMobile),
                const SizedBox(height: 16),
                _buildGradeTable(isMobile),
              ],
            )
          else
            // 데스크톱: 가로 배치
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildOxTable(isMobile),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _buildGradeTable(isMobile),
                ),
              ],
            ),
          const SizedBox(height: 16),
          // 액션 버튼
          _buildActionButtons(isMobile),
          // 저장 상태
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('저장 중...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (widget.sectionNumber != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2A44).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assessment,
              color: Color(0xFF1E2A44),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.sectionNumber != null
                    ? '${widget.sectionNumber}. 손상부 종합'
                    : '손상부 종합',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '구조적, 물리적, 생물·화학적 손상을 종합적으로 분석합니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoGradeToggle() {
    return Row(
      children: [
        Switch(
          value: _autoGradeEnabled,
          onChanged: (value) {
            setState(() {
              _autoGradeEnabled = value;
            });
            _saveToFirestore();
          },
        ),
        const SizedBox(width: 8),
        const Text(
          '자동 등급 계산',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  /// O/X 테이블
  Widget _buildOxTable(bool isMobile) {
    if (_rowIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '행을 추가해 주세요.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 고정 헤더
          _buildOxTableHeader(isMobile),
          // 스크롤 가능한 본문
          LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              final maxTableHeight = isMobile 
                  ? (screenHeight * 0.4).clamp(200.0, 400.0)
                  : (screenHeight * 0.5).clamp(300.0, 600.0);
              
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxTableHeight),
                child: Scrollbar(
                  controller: _verticalScrollController,
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: _buildOxTableBody(isMobile),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOxTableHeader(bool isMobile) {
    final minHeaderWidth = 120.0 +
        (_structuralColumns.length * 100.0) +
        (_physicalColumns.length * 100.0) +
        (_biochemicalColumns.length * 100.0);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF333333),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
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

  Widget _buildOxTableBody(bool isMobile) {
    final minTableWidth = 120.0 +
        (_structuralColumns.length * 100.0) +
        (_physicalColumns.length * 100.0) +
        (_biochemicalColumns.length * 100.0);

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minTableWidth),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300),
        columnWidths: {
          0: const FixedColumnWidth(120),
          for (int i = 1; i <= _allColumns.length + 3; i++)
            i: const FixedColumnWidth(100),
        },
        children: [
          for (int index = 0; index < _rowIds.length; index++)
            _buildOxDataRow(_rowIds[index], index, isMobile),
        ],
      ),
    );
  }

  TableRow _buildOxDataRow(String rowId, int index, bool isMobile) {
    return TableRow(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : const Color(0xFFF9FAFB),
      ),
      children: [
        // 손상 유형 (구성 요소 이름)
        _buildLabelCell('구성 요소 ${index + 1}', isMobile),
        // 구조적 손상 그룹 헤더 (빈 셀)
        _buildTableCell('', isMobile),
        // 구조적 손상 데이터
        ..._structuralColumns.map((col) => _buildOxCell(rowId, col, isMobile)),
        // 물리적 손상 그룹 헤더 (빈 셀)
        _buildTableCell('', isMobile),
        // 물리적 손상 데이터
        ..._physicalColumns.map((col) => _buildOxCell(rowId, col, isMobile)),
        // 생물·화학적 손상 그룹 헤더 (빈 셀)
        _buildTableCell('', isMobile),
        // 생물·화학적 손상 데이터
        ..._biochemicalColumns.map((col) => _buildOxCell(rowId, col, isMobile)),
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

  Widget _buildTableCell(String text, bool isMobile, {bool isHeader = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
        color: isHeader ? const Color(0xFFE5E5E5) : Colors.transparent,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildOxCell(String rowId, String columnId, bool isMobile) {
    final key = '${rowId}_$columnId';
    final controller = _oxControllers[key] ?? TextEditingController();
    final focusNode = _oxFocusNodes[key] ?? FocusNode();
    final value = _oxTable[rowId]?[columnId] ?? '';
    final isValid = _isValidOxValue(value);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
        color: isValid ? Colors.transparent : Colors.red.shade50,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isMobile ? 11 : 13,
          fontWeight: FontWeight.w500,
        ),
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
          _onOxChanged(rowId, columnId, value);
        },
        onSubmitted: (value) {
          final normalized = DamageGradeCalculator.normalizeOxValue(value);
          controller.text = normalized;
          _onOxChanged(rowId, columnId, normalized);
        },
      ),
    );
  }

  bool _isValidOxValue(String value) {
    if (value.isEmpty) return true;
    return DamageGradeCalculator.isValidOxValue(value);
  }

  /// 손상등급 테이블
  Widget _buildGradeTable(bool isMobile) {
    if (_rowIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '행을 추가해 주세요.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

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
            decoration: const BoxDecoration(
              color: Color(0xFF333333),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: const Text(
              '손상등급',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // 본문
          LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              final maxTableHeight = isMobile 
                  ? (screenHeight * 0.3).clamp(150.0, 300.0)
                  : (screenHeight * 0.4).clamp(200.0, 500.0);
              
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxTableHeight),
                child: SingleChildScrollView(
                  child: _buildGradeTableBody(isMobile),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGradeTableBody(bool isMobile) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: {
        0: const FixedColumnWidth(80),
        1: const FixedColumnWidth(60),
        2: const FixedColumnWidth(60),
        3: const FixedColumnWidth(60),
        4: const FixedColumnWidth(60),
      },
      children: [
        // 헤더 행
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFFE5E5E5),
          ),
          children: [
            _buildTableCell('', isMobile),
            _buildTableCell('A', isMobile, isHeader: true),
            _buildTableCell('B', isMobile, isHeader: true),
            _buildTableCell('C', isMobile, isHeader: true),
            _buildTableCell('D', isMobile, isHeader: true),
          ],
        ),
        // 데이터 행 (각 구성 요소마다 육안/심화 2행)
        for (int index = 0; index < _rowIds.length; index++)
          ..._buildGradeRowsForComponent(_rowIds[index], index, isMobile),
      ],
    );
  }

  List<TableRow> _buildGradeRowsForComponent(
    String rowId,
    int index,
    bool isMobile,
  ) {
    final grades = _damageGrades[rowId] ?? {'visual': 'A', 'advanced': 'A'};
    final visualGrade = grades['visual'] ?? 'A';
    final advancedGrade = grades['advanced'] ?? 'A';
    final isEditable = !_autoGradeEnabled;

    return [
      // 육안 행 (녹색)
      TableRow(
        decoration: BoxDecoration(
          color: Colors.green.shade50,
        ),
        children: [
          _buildTableCell('육안', isMobile),
          _buildGradeRadioCell(
            rowId,
            'visual',
            'A',
            visualGrade == 'A',
            Colors.green,
            isEditable,
            isMobile,
          ),
          _buildGradeRadioCell(
            rowId,
            'visual',
            'B',
            visualGrade == 'B',
            Colors.green,
            isEditable,
            isMobile,
          ),
          _buildGradeRadioCell(
            rowId,
            'visual',
            'C',
            visualGrade == 'C',
            Colors.green,
            isEditable,
            isMobile,
          ),
          _buildGradeRadioCell(
            rowId,
            'visual',
            'D',
            visualGrade == 'D',
            Colors.green,
            isEditable,
            isMobile,
          ),
        ],
      ),
      // 심화 행 (주황)
      TableRow(
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
        ),
        children: [
          _buildTableCell('심화', isMobile),
          _buildGradeRadioCell(
            rowId,
            'advanced',
            'A',
            advancedGrade == 'A',
            Colors.orange,
            isEditable,
            isMobile,
          ),
          _buildGradeRadioCell(
            rowId,
            'advanced',
            'B',
            advancedGrade == 'B',
            Colors.orange,
            isEditable,
            isMobile,
          ),
          _buildGradeRadioCell(
            rowId,
            'advanced',
            'C',
            advancedGrade == 'C',
            Colors.orange,
            isEditable,
            isMobile,
          ),
          _buildGradeRadioCell(
            rowId,
            'advanced',
            'D',
            advancedGrade == 'D',
            Colors.orange,
            isEditable,
            isMobile,
          ),
        ],
      ),
    ];
  }

  Widget _buildGradeRadioCell(
    String rowId,
    String type,
    String grade,
    bool isSelected,
    Color groupColor,
    bool isEditable,
    bool isMobile,
  ) {
    final gradeColor = _getGradeColor(grade);

    return Container(
      padding: EdgeInsets.all(isMobile ? 4 : 6),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
        color: isSelected ? gradeColor.withOpacity(0.2) : Colors.transparent,
      ),
      child: isEditable
          ? InkWell(
              onTap: () => _onGradeChanged(rowId, type, grade),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? gradeColor : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? gradeColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            )
          : Center(
              child: Text(
                isSelected ? grade : '',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  color: gradeColor,
                ),
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

  Widget _buildActionButtons(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _rowIds.isEmpty ? null : () {
              if (_rowIds.isNotEmpty) {
                _removeRow(_rowIds.last);
              }
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('행 삭제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _rowIds.isEmpty ? Colors.grey : Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _addNewRow,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('행 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2A44),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveToFirestore,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('저장'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B6CB7),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    } else {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _rowIds.isEmpty ? null : () {
              if (_rowIds.isNotEmpty) {
                _removeRow(_rowIds.last);
              }
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('행 삭제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _rowIds.isEmpty ? Colors.grey : Colors.red,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _addNewRow,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('행 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2A44),
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveToFirestore,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('저장'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B6CB7),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }
  }
}

