import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_cross_app/core/services/firebase_service.dart';
import 'package:my_cross_app/core/theme/app_theme.dart';
import 'package:my_cross_app/core/ui/components/section_button.dart';
import 'package:my_cross_app/core/ui/components/section_card.dart';
import 'package:my_cross_app/core/ui/section_form/section_data_list.dart';
import 'package:my_cross_app/core/ui/widgets/ox_toggle.dart';
import 'package:my_cross_app/core/ui/widgets/responsive_table.dart';
import 'package:my_cross_app/models/heritage_detail_models.dart';
import 'package:my_cross_app/models/section_form_models.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/cards/damage_summary_table_v2.dart';

class DamageSummaryTable extends StatefulWidget {
  const DamageSummaryTable({
    super.key,
    this.sectionNumber,
    required this.value,
    required this.onChanged,
    this.heritageId = '',
    this.heritageName = '',
  });

  final int? sectionNumber;
  final DamageSummary value;
  final ValueChanged<DamageSummary> onChanged;
  final String heritageId;
  final String heritageName;

  @override
  State<DamageSummaryTable> createState() => _DamageSummaryTableState();
}

class _DamageSummaryTableState extends State<DamageSummaryTable> {
  final List<TextEditingController> _labelControllers = [];
  static const List<String> _gradeOptions = [
    'A',
    'B',
    'C1',
    'C2',
    'D',
    'E',
    'F',
  ];
  static const List<String> _positionOptions = ['-', 'X', 'O'];

  final _fb = FirebaseService();
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String? _saveStatusMessage;
  Timer? _autoSaveTimer;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant DamageSummaryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value.rows.length != widget.value.rows.length) {
      _syncControllers();
    } else {
      for (var i = 0; i < _labelControllers.length; i++) {
        final updated = widget.value.rows[i].label;
        if (_labelControllers[i].text != updated) {
          _labelControllers[i].text = updated;
        }
      }
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final controller in _labelControllers) {
      controller.dispose();
    }
    _labelControllers.clear();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = _buildColumns();
    final rows = _buildRows(columns);
    final textTheme = Theme.of(context).textTheme;

    return SectionCard(
      sectionNumber: widget.sectionNumber,
      title: '손상부 종합',
      sectionDescription: '구조적, 물리적, 생물·화학적 손상을 종합적으로 분석합니다',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_saveStatusMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _saveStatusMessage!.contains('✅') 
                    ? Colors.green.shade50 
                    : _saveStatusMessage!.contains('❌')
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _saveStatusMessage!.contains('✅')
                      ? Colors.green.shade300
                      : _saveStatusMessage!.contains('❌')
                          ? Colors.red.shade300
                          : Colors.blue.shade300,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSaving)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_saveStatusMessage!.contains('✅'))
                    const Icon(Icons.check_circle, size: 16, color: Colors.green)
                  else if (_saveStatusMessage!.contains('❌'))
                    const Icon(Icons.error, size: 16, color: Colors.red)
                  else
                    const Icon(Icons.info, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    _saveStatusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _saveStatusMessage!.contains('✅')
                          ? Colors.green.shade700
                          : _saveStatusMessage!.contains('❌')
                              ? Colors.red.shade700
                              : Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SectionButtonGroup(
            spacing: 8,
            buttons: [
              if (!widget.value.rows.isEmpty)
                SectionButton.outlined(
                  label: '행 삭제',
                  onPressed: () {
                    final rows = List<DamageRow>.from(widget.value.rows)
                      ..removeLast();
                    widget.onChanged(widget.value.copyWith(rows: rows));
                    _markAsChanged();
                  },
                  icon: Icons.delete_forever_outlined,
                  color: Colors.red,
                ),
              SectionButton.filled(
                label: '행 추가',
                onPressed: () {
                  _addRow();
                  _markAsChanged();
                },
                icon: Icons.add,
              ),
              SectionButton.filled(
                label: _isSaving ? '저장 중...' : '저장',
                onPressed: _isSaving
                    ? () {}
                    : () => _saveDamageSummary(showMessage: true),
                icon: _isSaving ? Icons.hourglass_empty : Icons.save,
                backgroundColor: _hasUnsavedChanges ? Colors.orange : null,
              ),
            ],
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1200;
          final editorPanel = _buildPanel(
            title: '① 손상부 기록표',
            description: '구조·물리·생물·화학 손상 입력을 모두 한 번에 관리합니다.',
            child: _buildEditableTable(columns, rows),
          );
          final previewPanel = _buildPanel(
            title: '② 보고서 미리보기',
            description: '입력된 데이터를 보고서 레이아웃으로 즉시 확인하세요.',
            child: DamageSummaryTableV2(value: widget.value),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: editorPanel),
                    const SizedBox(width: 24),
                    Expanded(child: previewPanel),
                  ],
                )
              else ...[
                editorPanel,
                const SizedBox(height: 24),
                previewPanel,
              ],
              const SizedBox(height: 16),
              if (widget.heritageId.isNotEmpty)
                SectionDataList(
                  heritageId: widget.heritageId,
                  sectionType: SectionType.damage,
                  sectionTitle: '손상부 종합',
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    String? description,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final borderColor = theme.dividerColor.withOpacity(0.4);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildEditableTable(List<DataColumn> columns, List<DataRow> rows) {
    final borderColor = Theme.of(context).dividerColor.withOpacity(0.6);
    final dataTable = DataTable(
      columns: columns,
      rows: rows,
      dataRowMinHeight: 140, // 행 높이 증가
      headingRowHeight: 80, // 헤더 높이 증가
      horizontalMargin: 12,
      columnSpacing: 16, // 컬럼 간격 증가
      headingTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryText,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면 높이에 따라 테이블 최소 높이 설정
        final screenHeight = MediaQuery.of(context).size.height;
        final minTableHeight = screenHeight * 0.5; // 화면 높이의 50%
        final maxTableHeight = screenHeight * 0.75; // 화면 높이의 75%
        
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minTableHeight.clamp(400.0, 600.0),
                maxHeight: maxTableHeight.clamp(500.0, 800.0),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: minTableHeight.clamp(400.0, 600.0),
                  ),
                  child: ResponsiveTable(
                    controller: _horizontalScrollController,
                    minWidth: _editorTableMinWidth(),
                    child: dataTable,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _editorTableMinWidth() {
    final toggleColumnCount =
        widget.value.columnsStructural.length +
        widget.value.columnsPhysical.length +
        widget.value.columnsBioChemical.length;
    const labelWidth = 220.0;
    const toggleWidth = 120.0;
    const gradeWidth = 110.0;
    final width =
        labelWidth + (toggleColumnCount * toggleWidth) + (3 * gradeWidth);
    return width.clamp(720.0, 2000.0).toDouble();
  }

  List<DataColumn> _buildColumns() {
    return [
      const DataColumn(
        label: _ColumnHeader(group: '구성 요소', column: '위치'),
      ),
      ...widget.value.columnsStructural.map(
        (label) => DataColumn(
          label: _ColumnHeader(
            group: '구조적 손상',
            column: label,
            groupColor: Colors.red,
          ),
        ),
      ),
      ...widget.value.columnsPhysical.map(
        (label) => DataColumn(
          label: _ColumnHeader(
            group: '물리적 손상',
            column: label,
            groupColor: Colors.blue,
          ),
        ),
      ),
      ...widget.value.columnsBioChemical.map(
        (label) => DataColumn(
          label: _ColumnHeader(
            group: '생물·화학적 손상',
            column: label,
            groupColor: Colors.green,
          ),
        ),
      ),
      const DataColumn(
        label: _ColumnHeader(group: '육안 등급', column: '육안'),
      ),
      const DataColumn(
        label: _ColumnHeader(group: '실험실 등급', column: '실험실'),
      ),
      const DataColumn(
        label: _ColumnHeader(group: '최종 등급', column: '최종'),
      ),
    ];
  }

  List<DataRow> _buildRows(List<DataColumn> columns) {
    if (widget.value.rows.isEmpty) {
      return [
        DataRow(
          cells: [
            const DataCell(Text('행을 추가해 주세요.')),
            ...List.generate(
              columns.length - 1,
              (_) => const DataCell(SizedBox.shrink()),
            ),
          ],
        ),
      ];
    }

    final List<DataRow> rows = [];
    for (var index = 0; index < widget.value.rows.length; index++) {
      final row = widget.value.rows[index];
      final cells = <DataCell>[
        DataCell(
          SizedBox(
            width: 180,
            child: TextFormField(
              controller: _labelControllers[index],
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E2A44), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                hintText: '구성 요소 이름 입력 (예: 기둥 01번)',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              onChanged: (value) {
                _replaceRow(index, row.copyWith(label: value));
                _markAsChanged();
              },
            ),
          ),
        ),
      ];

      void addToggleCell(
        Map<String, DamageCell> map,
        String label,
        String semantics,
        Color groupColor,
      ) {
        final cell = map[label] ?? const DamageCell();
        final present = cell.present;

        cells.add(
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Main toggle for present/absent - 더 큰 클릭 영역
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final updated = _updateMap(
                          map,
                          label,
                          cell.copyWith(present: !present),
                        );
                        if (map == row.structural) {
                          _replaceRow(index, row.copyWith(structural: updated));
                        } else if (map == row.physical) {
                          _replaceRow(index, row.copyWith(physical: updated));
                        } else {
                          _replaceRow(index, row.copyWith(bioChemical: updated));
                        }
                        _markAsChanged();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 56,
                        height: 36,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: present 
                              ? groupColor.withOpacity(0.15)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: present 
                                ? groupColor
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            present ? 'O' : 'X',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: present 
                                  ? groupColor
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Position indicators (상/중/하) - 더 큰 클릭 영역
                  if (present) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPositionButton(
                          '상',
                          cell.positionTop,
                          (value) => _updatePosition(
                            map,
                            label,
                            'top',
                            value,
                            index,
                            row,
                          ),
                          groupColor,
                        ),
                        _buildPositionButton(
                          '중',
                          cell.positionMiddle,
                          (value) => _updatePosition(
                            map,
                            label,
                            'middle',
                            value,
                            index,
                            row,
                          ),
                          groupColor,
                        ),
                        _buildPositionButton(
                          '하',
                          cell.positionBottom,
                          (value) => _updatePosition(
                            map,
                            label,
                            'bottom',
                            value,
                            index,
                            row,
                          ),
                          groupColor,
                        ),
                      ],
                    ),
                  ] else
                    // 빈 공간 유지
                    const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        );
      }

      for (final label in widget.value.columnsStructural) {
        addToggleCell(row.structural, label, '구조적 손상 $label', Colors.red);
      }
      for (final label in widget.value.columnsPhysical) {
        addToggleCell(row.physical, label, '물리적 손상 $label', Colors.blue);
      }
      for (final label in widget.value.columnsBioChemical) {
        addToggleCell(row.bioChemical, label, '생물·화학적 손상 $label', Colors.green);
      }

      cells.addAll([
        DataCell(
          SizedBox(
            width: 120,
            child: _gradeDropdown(
              value: row.visualGrade,
              onChanged: (value) {
                if (value == null) return;
                _replaceRow(index, row.copyWith(visualGrade: value));
                _markAsChanged();
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 120,
            child: _gradeDropdown(
              value: row.labGrade,
              onChanged: (value) {
                if (value == null) return;
                _replaceRow(index, row.copyWith(labGrade: value));
                _markAsChanged();
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 120,
            child: _gradeDropdown(
              value: row.finalGrade,
              onChanged: (value) {
                if (value == null) return;
                _replaceRow(index, row.copyWith(finalGrade: value));
                _markAsChanged();
              },
            ),
          ),
        ),
      ]);

      rows.add(DataRow(cells: cells));
    }
    return rows;
  }

  Widget _gradeDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      items: _gradeOptions
          .map((grade) => DropdownMenuItem(
                value: grade,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getGradeColor(grade),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          grade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(grade),
                  ],
                ),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1E2A44), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF4CAF50);
      case 'B':
        return const Color(0xFF8BC34A);
      case 'C1':
        return const Color(0xFFFFC107);
      case 'C2':
        return const Color(0xFFFF9800);
      case 'D':
        return const Color(0xFFFF5722);
      case 'E':
        return const Color(0xFF9C27B0);
      case 'F':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  Map<String, DamageCell> _updateMap(
    Map<String, DamageCell> source,
    String key,
    dynamic value,
  ) {
    if (value is bool) {
      return {
        for (final entry in source.entries)
          entry.key: entry.key == key
              ? entry.value.copyWith(present: value)
              : entry.value,
      };
    } else if (value is DamageCell) {
      return {
        for (final entry in source.entries)
          entry.key: entry.key == key ? value : entry.value,
      };
    }
    return source;
  }

  void _replaceRow(int index, DamageRow row) {
    final rows = List<DamageRow>.from(widget.value.rows);
    rows[index] = row;
    widget.onChanged(widget.value.copyWith(rows: rows));
  }

  void _addRow() {
    final makeMap = (List<String> keys) => {
      for (final key in keys) key: const DamageCell(),
    };
    final row = DamageRow(
      label: '구성 요소 ${widget.value.rows.length + 1}',
      structural: makeMap(widget.value.columnsStructural),
      physical: makeMap(widget.value.columnsPhysical),
      bioChemical: makeMap(widget.value.columnsBioChemical),
      visualGrade: '',
      labGrade: '',
      finalGrade: '',
    );
    final rows = List<DamageRow>.from(widget.value.rows)..add(row);
    widget.onChanged(widget.value.copyWith(rows: rows));
    _syncControllers();
  }

  void _syncControllers() {
    for (final controller in _labelControllers) {
      controller.dispose();
    }
    _labelControllers
      ..clear()
      ..addAll(
        widget.value.rows
            .map((row) => TextEditingController(text: row.label))
            .toList(),
      );
  }

  Widget _buildPositionButton(
    String positionLabel,
    String currentValue,
    ValueChanged<String> onChanged,
    Color groupColor,
  ) {
    final options = ['-', 'X', 'O'];
    final currentIndex = options.indexOf(currentValue);
    final nextIndex = (currentIndex + 1) % options.length;
    final nextValue = options[nextIndex];
    
    Color getColor(String value) {
      switch (value) {
        case 'O':
          return Colors.green;
        case 'X':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }
    
    Color getBgColor(String value) {
      switch (value) {
        case 'O':
          return Colors.green.shade50;
        case 'X':
          return Colors.red.shade50;
        default:
          return Colors.grey.shade100;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onChanged(nextValue);
          _markAsChanged();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: getBgColor(currentValue),
            shape: BoxShape.circle,
            border: Border.all(
              color: getColor(currentValue),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              currentValue,
              style: TextStyle(
                color: getColor(currentValue),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updatePosition(
    Map<String, DamageCell> map,
    String label,
    String position,
    String value,
    int index,
    DamageRow row,
  ) {
    final cell = map[label] ?? const DamageCell();
    final updatedCell = cell.copyWith(
      positionTop: position == 'top' ? value : cell.positionTop,
      positionMiddle: position == 'middle' ? value : cell.positionMiddle,
      positionBottom: position == 'bottom' ? value : cell.positionBottom,
    );

    final updated = _updateMap(map, label, updatedCell);
    if (map == row.structural) {
      _replaceRow(index, row.copyWith(structural: updated));
    } else if (map == row.physical) {
      _replaceRow(index, row.copyWith(physical: updated));
    } else {
      _replaceRow(index, row.copyWith(bioChemical: updated));
    }
  }

  /// 변경 사항 표시
  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
        _saveStatusMessage = '💾 변경 사항이 있습니다';
      });
    }
    
    // 자동 저장 타이머 시작 (2초 후 자동 저장)
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (widget.heritageId.isNotEmpty && _hasUnsavedChanges) {
        _saveDamageSummary(showMessage: false);
      }
    });
  }

  Future<void> _saveDamageSummary({bool showMessage = true}) async {
    if (widget.heritageId.isEmpty) {
      if (showMessage && mounted) {
        setState(() {
          _saveStatusMessage = '❌ 문화유산 정보가 없습니다';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _saveStatusMessage = null;
            });
          }
        });
      }
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      if (showMessage) {
        _saveStatusMessage = '💾 저장 중...';
      }
    });

    try {
      // 손상부 종합 데이터를 하나의 제목과 내용으로 결합
      final title = '손상부 종합 - ${DateTime.now().toString().substring(0, 16)}';
      final content = StringBuffer();

      for (int i = 0; i < widget.value.rows.length; i++) {
        final row = widget.value.rows[i];
        content.writeln('${i + 1}. ${row.label}');
        content.writeln('  - 육안등급: ${row.visualGrade}');
        content.writeln('  - 실험실등급: ${row.labGrade}');
        content.writeln('  - 최종등급: ${row.finalGrade}');

        // 구조부 손상
        final structuralDamages = <String>[];
        for (final entry in row.structural.entries) {
          if (entry.value.present) {
            final positions = <String>[];
            if (entry.value.positionTop != '-')
              positions.add('상:${entry.value.positionTop}');
            if (entry.value.positionMiddle != '-')
              positions.add('중:${entry.value.positionMiddle}');
            if (entry.value.positionBottom != '-')
              positions.add('하:${entry.value.positionBottom}');

            if (positions.isNotEmpty) {
              structuralDamages.add('${entry.key}(${positions.join(', ')})');
            } else {
              structuralDamages.add(entry.key);
            }
          }
        }
        if (structuralDamages.isNotEmpty) {
          content.writeln('  - 구조부 손상: ${structuralDamages.join(', ')}');
        }

        // 물리적 손상
        final physicalDamages = <String>[];
        for (final entry in row.physical.entries) {
          if (entry.value.present) {
            final positions = <String>[];
            if (entry.value.positionTop != '-')
              positions.add('상:${entry.value.positionTop}');
            if (entry.value.positionMiddle != '-')
              positions.add('중:${entry.value.positionMiddle}');
            if (entry.value.positionBottom != '-')
              positions.add('하:${entry.value.positionBottom}');

            if (positions.isNotEmpty) {
              physicalDamages.add('${entry.key}(${positions.join(', ')})');
            } else {
              physicalDamages.add(entry.key);
            }
          }
        }
        if (physicalDamages.isNotEmpty) {
          content.writeln('  - 물리적 손상: ${physicalDamages.join(', ')}');
        }

        // 생화학적 손상
        final bioChemicalDamages = <String>[];
        for (final entry in row.bioChemical.entries) {
          if (entry.value.present) {
            final positions = <String>[];
            if (entry.value.positionTop != '-')
              positions.add('상:${entry.value.positionTop}');
            if (entry.value.positionMiddle != '-')
              positions.add('중:${entry.value.positionMiddle}');
            if (entry.value.positionBottom != '-')
              positions.add('하:${entry.value.positionBottom}');

            if (positions.isNotEmpty) {
              bioChemicalDamages.add('${entry.key}(${positions.join(', ')})');
            } else {
              bioChemicalDamages.add(entry.key);
            }
          }
        }
        if (bioChemicalDamages.isNotEmpty) {
          content.writeln('  - 생화학적 손상: ${bioChemicalDamages.join(', ')}');
        }

        content.writeln('');
      }

      if (content.toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('입력된 손상부 데이터가 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final formData = SectionFormData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sectionType: SectionType.damage,
        title: title,
        content: content.toString().trim(),
        createdAt: DateTime.now(),
        author: '현재 사용자',
      );

      await _fb.saveSectionForm(
        heritageId: widget.heritageId,
        sectionType: SectionType.damage,
        formData: formData,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasUnsavedChanges = false;
          _saveStatusMessage = showMessage ? '✅ 저장되었습니다' : '✅ 자동 저장됨';
        });
        
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 손상부 종합이 저장되었습니다'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        // 상태 메시지 자동 제거
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _saveStatusMessage = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatusMessage = '❌ 저장 실패: ${e.toString().length > 30 ? e.toString().substring(0, 30) + "..." : e.toString()}';
        });
        
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('저장 실패: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        
        // 오류 메시지 자동 제거
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _saveStatusMessage = null;
            });
          }
        });
      }
    }
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.group,
    required this.column,
    this.groupColor,
  });

  final String group;
  final String column;
  final Color? groupColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: groupColor?.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: groupColor != null
                ? Border.all(color: groupColor!.withOpacity(0.3))
                : null,
          ),
          child: Text(
            group,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: groupColor ?? Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            column,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textWidthBasis: TextWidthBasis.longestLine,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: groupColor?.withOpacity(0.8) ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
