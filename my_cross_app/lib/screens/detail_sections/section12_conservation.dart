import 'package:flutter/material.dart';

import '../../services/survey_repository.dart';
import 'detail_sections_strings_ko.dart';

class Section12Conservation extends StatelessWidget {
  const Section12Conservation({
    super.key,
    required this.rows,
    required this.onChanged,
    this.enabled = true,
  });

  final List<Section12Row> rows;
  final ValueChanged<List<Section12Row>> onChanged;
  final bool enabled;

  void _updateRow(int index, Section12Row row) {
    final copy = List<Section12Row>.from(rows);
    copy[index] = row;
    onChanged(copy);
  }

  void _removeRow(int index) {
    final copy = List<Section12Row>.from(rows)..removeAt(index);
    onChanged(copy);
  }

  void _addRow() {
    onChanged([...rows, Section12Row.empty()]);
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(stringsKo['sec_12']!, style: headerStyle),
            if (enabled)
              FilledButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('행 추가'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildHeaderCell(stringsKo['group']!, flex: 2),
              _buildHeaderCell(stringsKo['part']!, flex: 2),
              _buildHeaderCell(stringsKo['content']!, flex: 4),
              _buildHeaderCell(stringsKo['photo_ref']!, flex: 2),
              const SizedBox(width: 36),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: const Text('등록된 내용이 없습니다.'),
          )
        else
          Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                _ConservationRow(
                  row: rows[i],
                  index: i,
                  enabled: enabled,
                  onChanged: (updated) => _updateRow(i, updated),
                  onRemove: () => _removeRow(i),
                ),
            ],
          ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: content,
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ConservationRow extends StatelessWidget {
  const _ConservationRow({
    required this.row,
    required this.index,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final Section12Row row;
  final int index;
  final bool enabled;
  final ValueChanged<Section12Row> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final fields = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          value: row.group,
          label: stringsKo['group']!,
          flex: 2,
          onChanged: (value) => onChanged(row.copyWith(group: value)),
        ),
        _buildField(
          value: row.part,
          label: stringsKo['part']!,
          flex: 2,
          onChanged: (value) => onChanged(row.copyWith(part: value)),
        ),
        _buildField(
          value: row.content,
          label: stringsKo['content']!,
          flex: 4,
          maxLines: 4,
          onChanged: (value) => onChanged(row.copyWith(content: value)),
        ),
        _buildField(
          value: row.ref,
          label: stringsKo['photo_ref']!,
          flex: 2,
          onChanged: (value) => onChanged(row.copyWith(ref: value)),
        ),
        if (enabled)
          IconButton(
            tooltip: '행 삭제',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          )
        else
          const SizedBox(width: 36),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: fields,
    );
  }

  Widget _buildField({
    required String value,
    required String label,
    required int flex,
    required ValueChanged<String> onChanged,
    int maxLines = 2,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: TextFormField(
          key: ValueKey('${row.id}-$label-$value'),
          enabled: enabled,
          initialValue: value,
          maxLines: maxLines,
          minLines: 1,
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
          ),
        ),
      ),
    );
  }
}
