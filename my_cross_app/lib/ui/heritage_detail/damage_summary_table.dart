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
  static const List<String> _gradeOptions = ['A', 'B', 'C', 'D', 'E', 'F'];
  
  final _fb = FirebaseService();
  bool _isSaving = false;

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
          label: _ColumnHeader(group: '구조적 손상', column: label),
        ),
      ),
      ...widget.value.columnsPhysical.map(
        (label) => DataColumn(
          label: _ColumnHeader(group: '물리적 손상', column: label),
        ),
      ),
      ...widget.value.columnsBioChemical.map(
        (label) => DataColumn(
          label: _ColumnHeader(group: '생물·화학적 손상', column: label),
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
                hintText: '손상 위치',
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
      ) {
        final present = map[label]?.present ?? false;
        cells.add(
          DataCell(
            Center(
              child: OxToggle(
                value: present,
                onChanged: (value) {
                  final updated = _updateMap(map, label, value);
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
            ),
          ),
        );
      }

      for (final label in widget.value.columnsStructural) {
        addToggleCell(row.structural, label, '구조적 손상 $label');
      }
      for (final label in widget.value.columnsPhysical) {
        addToggleCell(row.physical, label, '물리적 손상 $label');
      }
      for (final label in widget.value.columnsBioChemical) {
        addToggleCell(row.bioChemical, label, '생물·화학적 손상 $label');
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
    bool value,
  ) {
    return {
      for (final entry in source.entries)
        entry.key: entry.key == key
            ? entry.value.copyWith(present: value)
            : entry.value,
    };
  }

  void _replaceRow(int index, DamageRow row) {
    final rows = List<DamageRow>.from(widget.value.rows);
    rows[index] = row;
    widget.onChanged(widget.value.copyWith(rows: rows));
  }

  void _addRow() {
    const defaultLabel = '새 손상 위치';
    final makeMap = (List<String> keys) => {
      for (final key in keys) key: const DamageCell(),
    };
    final row = DamageRow(
      label: defaultLabel,
      structural: makeMap(widget.value.columnsStructural),
      physical: makeMap(widget.value.columnsPhysical),
      bioChemical: makeMap(widget.value.columnsBioChemical),
      visualGrade: 'E',
      labGrade: 'E',
      finalGrade: 'E',
    );
    final rows = List<DamageRow>.from(widget.value.rows)..add(row);
    widget.onChanged(widget.value.copyWith(rows: rows));
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
            structuralDamages.add(entry.key);
          }
        }
        if (structuralDamages.isNotEmpty) {
          content.writeln('  - 구조부 손상: ${structuralDamages.join(', ')}');
        }
        
        // 물리적 손상
        final physicalDamages = <String>[];
        for (final entry in row.physical.entries) {
          if (entry.value.present) {
            physicalDamages.add(entry.key);
          }
        }
        if (physicalDamages.isNotEmpty) {
          content.writeln('  - 물리적 손상: ${physicalDamages.join(', ')}');
        }
        
        // 생화학적 손상
        final bioChemicalDamages = <String>[];
        for (final entry in row.bioChemical.entries) {
          if (entry.value.present) {
            bioChemicalDamages.add(entry.key);
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
  const _ColumnHeader({required this.group, required this.column});

  final String group;
  final String column;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          group,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            column,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
