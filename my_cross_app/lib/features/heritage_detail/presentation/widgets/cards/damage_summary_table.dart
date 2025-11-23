import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_cross_app/core/services/firebase_service.dart';
import 'package:my_cross_app/core/theme/app_theme.dart';
import 'package:my_cross_app/core/ui/components/section_button.dart';
import 'package:my_cross_app/core/ui/components/section_card.dart';
import 'package:my_cross_app/core/ui/section_form/section_data_list.dart';
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

  final _fb = FirebaseService();
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String? _saveStatusMessage;
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

    return SectionCard(
      sectionNumber: widget.sectionNumber,
      title: '손상부 종합',
      sectionDescription: '구조적, 물리적, 생물·화학적 손상을 종합적으로 분석합니다',
      action: LayoutBuilder(
        builder: (context, constraints) {
          final isMobileAction = constraints.maxWidth < 600;
          return Column(
            crossAxisAlignment: isMobileAction
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상태 메시지 - 겹침 방지를 위한 명확한 마진
              if (_saveStatusMessage != null) ...[
                Container(
                  margin: EdgeInsets.only(bottom: isMobileAction ? 10 : 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobileAction ? 12 : 14,
                      vertical: isMobileAction ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: _saveStatusMessage!.contains('✅')
                          ? Colors.green.shade50
                          : _saveStatusMessage!.contains('❌')
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _saveStatusMessage!.contains('✅')
                            ? Colors.green.shade300
                            : _saveStatusMessage!.contains('❌')
                            ? Colors.red.shade300
                            : Colors.blue.shade300,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_saveStatusMessage!.contains('✅')
                                      ? Colors.green
                                      : _saveStatusMessage!.contains('❌')
                                      ? Colors.red
                                      : Colors.blue)
                                  .withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSaving)
                          SizedBox(
                            width: isMobileAction ? 14 : 16,
                            height: isMobileAction ? 14 : 16,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          )
                        else if (_saveStatusMessage!.contains('✅'))
                          Icon(
                            Icons.check_circle,
                            size: isMobileAction ? 16 : 18,
                            color: Colors.green,
                          )
                        else if (_saveStatusMessage!.contains('❌'))
                          Icon(
                            Icons.error,
                            size: isMobileAction ? 16 : 18,
                            color: Colors.red,
                          )
                        else
                          Icon(
                            Icons.info_outline,
                            size: isMobileAction ? 16 : 18,
                            color: Colors.blue,
                          ),
                        SizedBox(width: isMobileAction ? 6 : 8),
                        Flexible(
                          child: Text(
                            _saveStatusMessage!,
                            style: TextStyle(
                              fontSize: isMobileAction ? 11 : 13,
                              color: _saveStatusMessage!.contains('✅')
                                  ? Colors.green.shade700
                                  : _saveStatusMessage!.contains('❌')
                                  ? Colors.red.shade700
                                  : Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // 버튼 그룹 - 겹침 방지를 위한 명확한 레이아웃
              if (isMobileAction)
                // Mobile: 세로 배치, 전체 너비 사용
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.value.rows.isNotEmpty) ...[
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
                      const SizedBox(height: 10),
                    ],
                    SectionButton.filled(
                      label: '행 추가',
                      onPressed: () {
                        _addRow();
                        _markAsChanged();
                      },
                      icon: Icons.add,
                    ),
                    const SizedBox(height: 10),
                    SectionButton.filled(
                      label: _isSaving ? '저장 중...' : '저장',
                      onPressed: _isSaving
                          ? () {}
                          : () => _saveDamageSummary(showMessage: true),
                      icon: _isSaving ? Icons.hourglass_empty : Icons.save,
                      backgroundColor: _hasUnsavedChanges
                          ? Colors.orange
                          : null,
                    ),
                  ],
                )
              else
                // Desktop: 가로 배치, 버튼 크기 자동 조정
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    if (widget.value.rows.isNotEmpty)
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
                      backgroundColor: _hasUnsavedChanges
                          ? Colors.orange
                          : null,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1200;
          final isMobile = constraints.maxWidth < 600;
          final editorPanel = _buildPanel(
            title: '① 손상부 기록표',
            description: '구조·물리·생물·화학 손상 입력을 모두 한 번에 관리합니다.',
            child: _buildEditableTable(columns, rows, isMobile: isMobile),
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
                    SizedBox(width: isMobile ? 12 : 24),
                    Expanded(child: previewPanel),
                  ],
                )
              else ...[
                editorPanel,
                SizedBox(height: isMobile ? 16 : 24),
                previewPanel,
              ],
              SizedBox(height: isMobile ? 12 : 16),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: isMobile ? 6 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 12,
                    vertical: isMobile ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentBlue,
                      fontSize: isMobile ? 14 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              description,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryText,
                height: 1.4,
                fontSize: isMobile ? 11 : null,
              ),
            ),
          ],
          SizedBox(height: isMobile ? 12 : 16),
          child,
        ],
      ),
    );
  }

  Widget _buildEditableTable(
    List<DataColumn> columns,
    List<DataRow> rows, {
    bool isMobile = false,
  }) {
    final theme = Theme.of(context);
    final headingColor = const Color(0xFFF4F5F7);
    final tableCardRadius = isMobile ? 16.0 : 20.0;

    final dataTable = DataTable(
      columns: columns,
      rows: rows,
      dataRowMinHeight: isMobile ? 96 : 112,
      headingRowHeight: isMobile ? 64 : 74,
      horizontalMargin: isMobile ? 8 : 12,
      columnSpacing: isMobile ? 8 : 12,
      headingRowColor: WidgetStateProperty.all(headingColor),
      headingTextStyle: theme.textTheme.labelLarge?.copyWith(
        letterSpacing: 0.1,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF111827),
        fontSize: isMobile ? 12 : 13,
      ),
      dividerThickness: 0,
      border: TableBorder.symmetric(
        inside: BorderSide(color: Colors.transparent, width: 0),
        outside: BorderSide.none,
      ),
      dataTextStyle: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 13,
        color: const Color(0xFF1C1C1E),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final minTableHeight = screenHeight * 0.5;
        final maxTableHeight = screenHeight * 0.75;
        final minHeight = isMobile
            ? minTableHeight.clamp(280.0, 480.0)
            : minTableHeight.clamp(360.0, 620.0);
        final maxHeight = isMobile
            ? maxTableHeight.clamp(360.0, 560.0)
            : maxTableHeight.clamp(480.0, 780.0);

        final minWidth = _editorTableMinWidth();
        Widget tableContent;
        if (isMobile) {
          tableContent = Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            thickness: 6,
            radius: const Radius.circular(999),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: dataTable,
              ),
            ),
          );
        } else {
          tableContent = ResponsiveTable(
            controller: _horizontalScrollController,
            minWidth: minWidth,
            child: dataTable,
          );
        }

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF9FAFB), Color(0xFFF2F4F7)],
            ),
            borderRadius: BorderRadius.circular(tableCardRadius),
            border: Border.all(color: const Color(0xFFE3E5E9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tableCardRadius),
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: minHeight,
                    maxHeight: maxHeight,
                  ),
                  child: tableContent,
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
      DataColumn(
        label: const _ColumnHeader(group: '구성 요소', column: '위치'),
        numeric: false,
      ),
      ...widget.value.columnsStructural.map(
        (label) => DataColumn(
          label: _ColumnHeader(
            group: '구조적 손상',
            column: label,
            groupColor: Colors.red,
          ),
          numeric: false,
        ),
      ),
      ...widget.value.columnsPhysical.map(
        (label) => DataColumn(
          label: _ColumnHeader(
            group: '물리적 손상',
            column: label,
            groupColor: Colors.blue,
          ),
          numeric: false,
        ),
      ),
      ...widget.value.columnsBioChemical.map(
        (label) => DataColumn(
          label: _ColumnHeader(
            group: '생물·화학적 손상',
            column: label,
            groupColor: Colors.green,
          ),
          numeric: false,
        ),
      ),
      const DataColumn(
        label: _ColumnHeader(group: '육안 등급', column: '육안'),
        numeric: false,
      ),
      const DataColumn(
        label: _ColumnHeader(group: '실험실 등급', column: '실험실'),
        numeric: false,
      ),
      const DataColumn(
        label: _ColumnHeader(group: '최종 등급', column: '최종'),
        numeric: false,
      ),
    ];
  }

  List<DataRow> _buildRows(List<DataColumn> columns) {
    if (widget.value.rows.isEmpty) {
      return [
        DataRow.byIndex(
          index: 0,
          color: WidgetStateProperty.resolveWith((_) => Colors.white),
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
            width: MediaQuery.of(context).size.width < 600
                ? 150
                : 200, // Smaller on mobile
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
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2A44),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                hintText: '구성 요소 이름 입력 (예: 기둥 01번)',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
            // DamageCell: A dedicated component that ensures all content stays inside the cell
            // This prevents circular position buttons from overflowing below the table cell border
            _DamageCellContent(
              present: present,
              cell: cell,
              groupColor: groupColor,
              onTogglePresent: () {
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
              onUpdatePosition: (position, value) {
                _updatePosition(map, label, position, value, index, row);
              },
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
            width: 100, // Fixed width for consistent column alignment
            child: _gradeDropdown(
              value: row.visualGrade,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _replaceRow(index, row.copyWith(visualGrade: value));
                _markAsChanged();
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 100, // Fixed width for consistent column alignment
            child: _gradeDropdown(
              value: row.labGrade,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _replaceRow(index, row.copyWith(labGrade: value));
                _markAsChanged();
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 100, // Fixed width for consistent column alignment
            child: _gradeDropdown(
              value: row.finalGrade,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _replaceRow(index, row.copyWith(finalGrade: value));
                _markAsChanged();
              },
            ),
          ),
        ),
      ]);

      rows.add(
        DataRow.byIndex(
          index: index,
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFE0E7FF);
            }
            return index.isEven ? Colors.white : const Color(0xFFF7F8FA);
          }),
          cells: cells,
        ),
      );
    }
    return rows;
  }

  Widget _gradeDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      items: _gradeOptions
          .map(
            (grade) => DropdownMenuItem(
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
            ),
          )
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
    Map<String, DamageCell> makeMap(List<String> keys) {
      return {for (final key in keys) key: const DamageCell()};
    }

    final row = DamageRow(
      label: '', // 빈 문자열로 시작하여 사용자가 직접 입력
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
      positionLeft: position == 'left' ? value : cell.positionLeft,
      positionCenter: position == 'center' ? value : cell.positionCenter,
      positionRight: position == 'right' ? value : cell.positionRight,
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
    // 자동 저장 기능 제거됨
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
            if (entry.value.positionLeft != '-') {
              positions.add('좌:${entry.value.positionLeft}');
            }
            if (entry.value.positionCenter != '-') {
              positions.add('중:${entry.value.positionCenter}');
            }
            if (entry.value.positionRight != '-') {
              positions.add('우:${entry.value.positionRight}');
            }

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
            if (entry.value.positionLeft != '-') {
              positions.add('좌:${entry.value.positionLeft}');
            }
            if (entry.value.positionCenter != '-') {
              positions.add('중:${entry.value.positionCenter}');
            }
            if (entry.value.positionRight != '-') {
              positions.add('우:${entry.value.positionRight}');
            }

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
            if (entry.value.positionLeft != '-') {
              positions.add('좌:${entry.value.positionLeft}');
            }
            if (entry.value.positionCenter != '-') {
              positions.add('중:${entry.value.positionCenter}');
            }
            if (entry.value.positionRight != '-') {
              positions.add('우:${entry.value.positionRight}');
            }

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
      final rawError = e.toString();
      final shortError = rawError.length > 30
          ? '${rawError.substring(0, 30)}...'
          : rawError;

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatusMessage = '❌ 저장 실패: $shortError';
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

/// Dedicated widget for damage cell content that ensures all buttons stay inside the table cell.
///
/// This widget prevents circular position buttons from overflowing below the table cell border
/// by using strict constraints and clipping:
/// - Fixed vertical padding (8px top/bottom) ensures consistent spacing
/// - Column with mainAxisSize.min wraps content without forcing expansion
/// - ClipRect with Clip.hardEdge prevents any overflow from being visible
/// - Explicit height constraints ensure buttons never exceed cell boundaries
class _DamageCellContent extends StatelessWidget {
  const _DamageCellContent({
    required this.present,
    required this.cell,
    required this.groupColor,
    required this.onTogglePresent,
    required this.onUpdatePosition,
  });

  final bool present;
  final DamageCell cell;
  final Color groupColor;
  final VoidCallback onTogglePresent;
  final void Function(String position, String value) onUpdatePosition;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // Strict constraints: maximum height ensures buttons never overflow
      constraints: const BoxConstraints(
        maxHeight: 120, // Maximum cell height - buttons must fit within this
        minHeight: 100,
        maxWidth: 100,
        minWidth: 100,
      ),
      child: SizedBox(
        width: 100, // Fixed width for consistent column alignment
        child: ClipRect(
          clipBehavior: Clip
              .hardEdge, // Hard clip prevents any overflow from being visible
          child: Padding(
            // Reduced vertical padding to ensure buttons fit inside cell
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize:
                  MainAxisSize.min, // Wrap content, don't force expansion
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Main toggle for present/absent - reduced size to prevent overlap
                SizedBox(
                  width: 40,
                  height: 24,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTogglePresent,
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 24,
                        decoration: BoxDecoration(
                          color: present
                              ? groupColor.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: present ? groupColor : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: present
                              ? [
                                  BoxShadow(
                                    color: groupColor.withValues(alpha: 0.2),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            present ? 'O' : 'X',
                            style: TextStyle(
                              fontSize: 13,
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
                ),
                const SizedBox(height: 5),
                // Position indicators (좌/중앙/우측) - always visible, clickable to toggle O/X
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPositionButton(
                      '좌',
                      cell.positionLeft,
                      (value) => onUpdatePosition('left', value),
                      groupColor,
                    ),
                    const SizedBox(width: 3),
                    _buildPositionButton(
                      '중',
                      cell.positionCenter,
                      (value) => onUpdatePosition('center', value),
                      groupColor,
                    ),
                    const SizedBox(width: 3),
                    _buildPositionButton(
                      '우',
                      cell.positionRight,
                      (value) => onUpdatePosition('right', value),
                      groupColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionButton(
    String positionLabel,
    String currentValue,
    ValueChanged<String> onChanged,
    Color groupColor,
  ) {
    // O/X 직접 토글: '-' → 'O', 'O' → 'X', 'X' → 'O' (순환)
    // 사용자가 클릭하여 직접 O/X를 변경할 수 있음
    String getNextValue(String current) {
      if (current == '-') return 'O';
      if (current == 'O') return 'X';
      if (current == 'X') return 'O';
      return 'O'; // 기본값
    }

    Color getColor(String value) {
      switch (value) {
        case 'O':
          return Colors.green;
        case 'X':
          return Colors.red;
        default:
          return Colors.grey.shade400;
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

    return SizedBox(
      width: 24,
      height: 24,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onChanged(getNextValue(currentValue));
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            constraints: const BoxConstraints(
              maxWidth: 24,
              maxHeight: 24,
              minWidth: 24,
              minHeight: 24,
            ),
            decoration: BoxDecoration(
              color: getBgColor(currentValue),
              shape: BoxShape.circle,
              border: Border.all(color: getColor(currentValue), width: 2),
              boxShadow: currentValue != '-'
                  ? [
                      BoxShadow(
                        color: getColor(currentValue).withValues(alpha: 0.3),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                currentValue == '-' ? '-' : currentValue,
                style: TextStyle(
                  color: getColor(currentValue),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: groupColor?.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: groupColor != null
                ? Border.all(
                    color: groupColor!.withValues(alpha: 0.4),
                    width: 1.5,
                  )
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
              fontSize: 12,
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
              color: groupColor?.withValues(alpha: 0.8) ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
