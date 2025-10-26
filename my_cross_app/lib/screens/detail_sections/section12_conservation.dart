import 'package:flutter/material.dart';
import '../../models/survey_models.dart';
import 'detail_sections_strings_ko.dart';

class Section12Conservation extends StatefulWidget {
  final List<Section12Row> rows;
  final ValueChanged<List<Section12Row>> onChanged;
  final bool enabled;

  const Section12Conservation({
    super.key,
    required this.rows,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<Section12Conservation> createState() => _Section12ConservationState();
}

class _Section12ConservationState extends State<Section12Conservation> {
  late List<Section12Row> _rows;

  @override
  void initState() {
    super.initState();
    _rows = List.from(widget.rows);
  }

  @override
  void didUpdateWidget(Section12Conservation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows != oldWidget.rows) {
      _rows = List.from(widget.rows);
    }
  }

  void _updateRows(List<Section12Row> newRows) {
    setState(() {
      _rows = newRows;
    });
    widget.onChanged(newRows);
  }

  void _addRow() {
    final newRows = List<Section12Row>.from(_rows);
    newRows.add(Section12Row(
      group: '',
      part: '',
      content: '',
      photoRef: '',
    ));
    _updateRows(newRows);
  }

  void _removeRow(int index) {
    final newRows = List<Section12Row>.from(_rows);
    newRows.removeAt(index);
    _updateRows(newRows);
  }

  void _updateRow(int index, Section12Row newRow) {
    final newRows = List<Section12Row>.from(_rows);
    newRows[index] = newRow;
    _updateRows(newRows);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stringsKo['sec_12']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.enabled)
                  TextButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('행 추가'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Table header
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        stringsKo['group']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        stringsKo['part']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        stringsKo['content']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        stringsKo['photo_ref']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (widget.enabled)
                      const SizedBox(width: 40), // Space for delete button
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Table rows
            ..._rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return _buildRow(index, row);
            }),
            
            if (_rows.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.table_chart_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '보존사항이 없습니다',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      if (widget.enabled) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _addRow,
                          icon: const Icon(Icons.add),
                          label: const Text('첫 번째 항목 추가'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(int index, Section12Row row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: row.group,
              enabled: widget.enabled,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onChanged: (value) => _updateRow(
                index,
                Section12Row(
                  group: value,
                  part: row.part,
                  content: row.content,
                  photoRef: row.photoRef,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: row.part,
              enabled: widget.enabled,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onChanged: (value) => _updateRow(
                index,
                Section12Row(
                  group: row.group,
                  part: value,
                  content: row.content,
                  photoRef: row.photoRef,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: TextFormField(
              initialValue: row.content,
              enabled: widget.enabled,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onChanged: (value) => _updateRow(
                index,
                Section12Row(
                  group: row.group,
                  part: row.part,
                  content: value,
                  photoRef: row.photoRef,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: row.photoRef,
              enabled: widget.enabled,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onChanged: (value) => _updateRow(
                index,
                Section12Row(
                  group: row.group,
                  part: row.part,
                  content: row.content,
                  photoRef: value,
                ),
              ),
            ),
          ),
          if (widget.enabled) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _removeRow(index),
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}