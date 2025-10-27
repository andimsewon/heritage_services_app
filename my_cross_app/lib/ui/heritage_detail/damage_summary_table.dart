import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/heritage_detail_models.dart';
import '../../models/section_form_models.dart';
import '../../services/firebase_service.dart';
import '../../theme.dart';
import '../widgets/ox_toggle.dart';
import '../components/section_card.dart';
import '../components/section_button.dart';
import '../section_form/section_data_list.dart';

class DamageSummaryTable extends StatefulWidget {
  const DamageSummaryTable({
    super.key,
    required this.value,
    required this.onChanged,
    this.heritageId = '',
    this.heritageName = '',
  });

  final DamageSummary value;
  final ValueChanged<DamageSummary> onChanged;
  final String heritageId;
  final String heritageName;

  @override
  State<DamageSummaryTable> createState() => _DamageSummaryTableState();
}

class _DamageSummaryTableState extends State<DamageSummaryTable> {
  final List<TextEditingController> _labelControllers = [];
  static const List<String> _gradeOptions = ['A', 'B', 'C1', 'C2', 'D', 'E', 'F'];
  static const List<String> _positionOptions = ['-', 'X', 'O'];
  
  final _fb = FirebaseService();
  bool _isSaving = false;
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = _buildColumns();

    return SectionCard(
      title: '손상부 종합',
      action: SectionButtonGroup(
        spacing: 8,
        buttons: [
          SectionButton.outlined(
            label: '행 삭제',
            onPressed: widget.value.rows.isEmpty
                ? () {} // Disabled state
                : () {
                    final rows = List<DamageRow>.from(widget.value.rows)
                      ..removeLast();
                    widget.onChanged(widget.value.copyWith(rows: rows));
                  },
            icon: Icons.delete_forever_outlined,
            color: widget.value.rows.isEmpty ? Colors.grey : null,
          ),
          SectionButton.filled(
            label: '행 추가',
            onPressed: _addRow,
            icon: Icons.add,
          ),
          SectionButton.filled(
            label: _isSaving ? '저장 중...' : '저장',
            onPressed: _isSaving ? () {} : () => _saveDamageSummary(),
            icon: Icons.save,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '* 손상이 탐지된 경우 O / 아닌 경우 X 로 표기',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior(),
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 64,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  columnSpacing: 18,
                  border: TableBorder.all(color: AppTheme.tableDivider),
                  columns: columns,
                  rows: _buildRows(columns),
                ),
              ),
            ),
          ),
          // 저장된 데이터 리스트 표시
          if (widget.heritageId.isNotEmpty)
            SectionDataList(
              heritageId: widget.heritageId,
              sectionType: SectionType.damage,
              sectionTitle: '손상부 종합',
            ),
        ],
      ),
    );
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
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: '손상 위치를 입력하세요',
              ),
              onChanged: (value) {
                _replaceRow(index, row.copyWith(label: value));
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
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main toggle for present/absent
                  OxToggle(
                    value: present,
                    onChanged: (value) {
                      final updated = _updateMap(map, label, cell.copyWith(present: value));
                      if (map == row.structural) {
                        _replaceRow(index, row.copyWith(structural: updated));
                      } else if (map == row.physical) {
                        _replaceRow(index, row.copyWith(physical: updated));
                      } else {
                        _replaceRow(index, row.copyWith(bioChemical: updated));
                      }
                    },
                    label: '$semantics • ${row.label}',
                  ),
                  const SizedBox(height: 4),
                  // Position indicators (상/중/하)
                  if (present) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPositionIndicator(
                          '상', 
                          cell.positionTop, 
                          (value) => _updatePosition(map, label, 'top', value, index, row),
                          groupColor,
                        ),
                        _buildPositionIndicator(
                          '중', 
                          cell.positionMiddle, 
                          (value) => _updatePosition(map, label, 'middle', value, index, row),
                          groupColor,
                        ),
                        _buildPositionIndicator(
                          '하', 
                          cell.positionBottom, 
                          (value) => _updatePosition(map, label, 'bottom', value, index, row),
                          groupColor,
                        ),
                      ],
                    ),
                  ],
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
      value: value,
      items: _gradeOptions
          .map((grade) => DropdownMenuItem(value: grade, child: Text(grade)))
          .toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
    );
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
      label: '', // Empty label instead of hardcoded text
      structural: makeMap(widget.value.columnsStructural),
      physical: makeMap(widget.value.columnsPhysical),
      bioChemical: makeMap(widget.value.columnsBioChemical),
      visualGrade: 'E',
      labGrade: 'E',
      finalGrade: 'E',
    );
    final rows = List<DamageRow>.from(widget.value.rows)..add(row);
    widget.onChanged(widget.value.copyWith(rows: rows));
    
    // Smooth scroll to the newly added row
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
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

  Widget _buildPositionIndicator(
    String positionLabel,
    String currentValue,
    ValueChanged<String> onChanged,
    Color groupColor,
  ) {
    return Container(
      width: 40,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: groupColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isDense: true,
          items: _positionOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Center(
                child: Text(
                  option,
                  style: TextStyle(
                    color: option == 'O' ? Colors.green : 
                           option == 'X' ? Colors.red : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
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

  Future<void> _saveDamageSummary() async {
    if (widget.heritageId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문화유산 정보가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

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
            if (entry.value.positionTop != '-') positions.add('상:${entry.value.positionTop}');
            if (entry.value.positionMiddle != '-') positions.add('중:${entry.value.positionMiddle}');
            if (entry.value.positionBottom != '-') positions.add('하:${entry.value.positionBottom}');
            
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
            if (entry.value.positionTop != '-') positions.add('상:${entry.value.positionTop}');
            if (entry.value.positionMiddle != '-') positions.add('중:${entry.value.positionMiddle}');
            if (entry.value.positionBottom != '-') positions.add('하:${entry.value.positionBottom}');
            
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
            if (entry.value.positionTop != '-') positions.add('상:${entry.value.positionTop}');
            if (entry.value.positionMiddle != '-') positions.add('중:${entry.value.positionMiddle}');
            if (entry.value.positionBottom != '-') positions.add('하:${entry.value.positionBottom}');
            
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 손상부 종합이 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
            textAlign: TextAlign.center,
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
