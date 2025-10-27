import 'package:flutter/material.dart';
import '../../models/survey_models.dart';
import '../../widgets/kv_row.dart';
import 'detail_sections_strings_ko.dart';

class Section11Investigation extends StatefulWidget {
  final Section11Data data;
  final ValueChanged<Section11Data> onChanged;
  final bool enabled;

  const Section11Investigation({
    super.key,
    required this.data,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<Section11Investigation> createState() => _Section11InvestigationState();
}

class _Section11InvestigationState extends State<Section11Investigation> {
  late Section11Data _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }

  @override
  void didUpdateWidget(Section11Investigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _data = widget.data;
    }
  }

  void _updateData(Section11Data newData) {
    setState(() {
      _data = newData;
    });
    widget.onChanged(newData);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stringsKo['sec_11']!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Foundation section
            _buildTextListSection(
              stringsKo['foundation']!,
              _data.foundation,
              (value) => _updateData(_data.copyWith(foundation: value)),
            ),
            
            const SizedBox(height: 16),
            
            // Wall section
            _buildTextListSection(
              stringsKo['wall']!,
              _data.wall,
              (value) => _updateData(_data.copyWith(wall: value)),
            ),
            
            const SizedBox(height: 16),
            
            // Roof section
            _buildTextListSection(
              stringsKo['roof']!,
              _data.roof,
              (value) => _updateData(_data.copyWith(roof: value)),
            ),
            
            const SizedBox(height: 16),
            
            // Paint section
            _buildTextListSection(
              stringsKo['paint']!,
              _data.paint,
              (value) => _updateData(_data.copyWith(paint: value)),
            ),
            
            const SizedBox(height: 16),
            
            // Pest section
            _buildPestSection(),
            
            const SizedBox(height: 16),
            
            // Etc section
            _buildTextListSection(
              stringsKo['etc']!,
              _data.etc,
              (value) => _updateData(_data.copyWith(etc: value)),
            ),
            
            const SizedBox(height: 16),
            
            // Safety notes section
            _buildTextListSection(
              stringsKo['safetyNotes']!,
              _data.safetyNotes,
              (value) => _updateData(_data.copyWith(safetyNotes: value)),
            ),
            
            const SizedBox(height: 16),
            
            // Investigator opinion
            KeyValueRow(
              title: stringsKo['investigatorOpinion']!,
              enabled: widget.enabled,
              value: TextFormField(
                initialValue: _data.investigatorOpinion,
                enabled: widget.enabled,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '조사자의 종합적인 의견을 입력하세요',
                ),
                onChanged: (value) => _updateData(_data.copyWith(investigatorOpinion: value)),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Grade section
            _buildGradeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextListSection(
    String title,
    Map<String, List<Map<String, String>>> data,
    ValueChanged<Map<String, List<Map<String, String>>>> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...data.entries.map((entry) => _buildTextListEntry(
          entry.key,
          entry.value,
          (value) {
            final newData = Map<String, List<Map<String, String>>>.from(data);
            newData[entry.key] = value;
            onChanged(newData);
          },
        )),
        if (widget.enabled)
          TextButton.icon(
            onPressed: () {
              final newData = Map<String, List<Map<String, String>>>.from(data);
              newData['새 항목'] = [{'text': ''}];
              onChanged(newData);
            },
            icon: const Icon(Icons.add),
            label: const Text('항목 추가'),
          ),
      ],
    );
  }

  Widget _buildTextListEntry(
    String key,
    List<Map<String, String>> items,
    ValueChanged<List<Map<String, String>>> onChanged,
  ) {
    return Column(
      children: [
        Text(
          key,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item['text'] ?? '',
                  enabled: widget.enabled,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onChanged: (value) {
                    final newItems = List<Map<String, String>>.from(items);
                    newItems[index] = {'text': value};
                    onChanged(newItems);
                  },
                ),
              ),
              if (widget.enabled)
                IconButton(
                  onPressed: () {
                    final newItems = List<Map<String, String>>.from(items);
                    newItems.removeAt(index);
                    onChanged(newItems);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildPestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['pest']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _data.pest['hasPest'] == true,
              onChanged: widget.enabled
                  ? (value) {
                      final newPest = Map<String, dynamic>.from(_data.pest);
                      newPest['hasPest'] = value ?? false;
                      _updateData(_data.copyWith(pest: newPest));
                    }
                  : null,
            ),
            const Text('충해 발견'),
          ],
        ),
        if (_data.pest['hasPest'] == true)
          TextFormField(
            initialValue: _data.pest['note'] ?? '',
            enabled: widget.enabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '충해 상세 내용을 입력하세요',
            ),
            onChanged: (value) {
              final newPest = Map<String, dynamic>.from(_data.pest);
              newPest['note'] = value;
              _updateData(_data.copyWith(pest: newPest));
            },
          ),
      ],
    );
  }

  Widget _buildGradeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['grade']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _data.grade['value'] ?? '',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '등급',
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('선택하세요')),
                  DropdownMenuItem(value: 'A', child: Text('A')),
                  DropdownMenuItem(value: 'B', child: Text('B')),
                  DropdownMenuItem(value: 'C1', child: Text('C1')),
                  DropdownMenuItem(value: 'C2', child: Text('C2')),
                  DropdownMenuItem(value: 'D', child: Text('D')),
                  DropdownMenuItem(value: 'E', child: Text('E')),
                  DropdownMenuItem(value: 'F', child: Text('F')),
                ],
                onChanged: widget.enabled
                    ? (value) {
                        final newGrade = Map<String, dynamic>.from(_data.grade);
                        newGrade['value'] = value ?? '';
                        _updateData(_data.copyWith(grade: newGrade));
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: _data.grade['note'] ?? '',
                enabled: widget.enabled,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '비고',
                ),
                onChanged: (value) {
                  final newGrade = Map<String, dynamic>.from(_data.grade);
                  newGrade['note'] = value;
                  _updateData(_data.copyWith(grade: newGrade));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}