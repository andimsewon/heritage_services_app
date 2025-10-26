import 'package:flutter/material.dart';

import '../../services/survey_repository.dart';
import 'detail_sections_strings_ko.dart';

class Section11Investigation extends StatefulWidget {
  const Section11Investigation({
    super.key,
    required this.data,
    required this.onChanged,
    this.enabled = true,
  });

  final Section11Data data;
  final ValueChanged<Section11Data> onChanged;
  final bool enabled;

  @override
  State<Section11Investigation> createState() => _Section11InvestigationState();
}

class _Section11InvestigationState extends State<Section11Investigation> {
  late final TextEditingController _foundation;
  late final TextEditingController _wall;
  late final TextEditingController _roof;
  late final TextEditingController _paint;
  late final TextEditingController _etc;
  late final TextEditingController _safety;
  late final TextEditingController _pestNote;
  late final TextEditingController _opinion;
  late final TextEditingController _gradeNote;

  @override
  void initState() {
    super.initState();
    _foundation = TextEditingController();
    _wall = TextEditingController();
    _roof = TextEditingController();
    _paint = TextEditingController();
    _etc = TextEditingController();
    _safety = TextEditingController();
    _pestNote = TextEditingController();
    _opinion = TextEditingController();
    _gradeNote = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant Section11Investigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _foundation.dispose();
    _wall.dispose();
    _roof.dispose();
    _paint.dispose();
    _etc.dispose();
    _safety.dispose();
    _pestNote.dispose();
    _opinion.dispose();
    _gradeNote.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _sync(_foundation, widget.data.foundation);
    _sync(_wall, widget.data.wall);
    _sync(_roof, widget.data.roof);
    _sync(_paint, widget.data.paint);
    _sync(_etc, widget.data.etc);
    _sync(_safety, widget.data.safetyNotes);
    if (_pestNote.text != widget.data.pest.note) {
      _pestNote.text = widget.data.pest.note;
    }
    if (_opinion.text != widget.data.investigatorOpinion) {
      _opinion.text = widget.data.investigatorOpinion;
    }
    if (_gradeNote.text != widget.data.grade.note) {
      _gradeNote.text = widget.data.grade.note;
    }
  }

  void _sync(TextEditingController controller, List<String> values) {
    final joined = values.join('\n');
    if (controller.text != joined) {
      controller.text = joined;
    }
  }

  List<String> _split(String value) => value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  void _emit(Section11Data data) => widget.onChanged(data);

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              stringsKo['sec_11']!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildMultiline(stringsKo['foundation']!, _foundation, (value) {
              _emit(widget.data.copyWith(foundation: _split(value)));
            }),
            _buildMultiline(stringsKo['wall']!, _wall, (value) {
              _emit(widget.data.copyWith(wall: _split(value)));
            }),
            _buildMultiline(stringsKo['roof']!, _roof, (value) {
              _emit(widget.data.copyWith(roof: _split(value)));
            }),
            _buildMultiline(stringsKo['paint']!, _paint, (value) {
              _emit(widget.data.copyWith(paint: _split(value)));
            }),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              title: Text(stringsKo['pest']!),
              value: widget.data.pest.hasPest,
              onChanged: widget.enabled
                  ? (value) => _emit(
                        widget.data
                            .copyWith(pest: widget.data.pest.copyWith(hasPest: value)),
                      )
                  : null,
            ),
            _buildTextField(
              hint: '충해가 있는 경우 상세 내용을 작성하세요.',
              controller: _pestNote,
              label: '${stringsKo['pest']} 메모',
              onChanged: (value) => _emit(
                widget.data.copyWith(
                  pest: widget.data.pest.copyWith(note: value),
                ),
              ),
            ),
            _buildMultiline(stringsKo['etc']!, _etc, (value) {
              _emit(widget.data.copyWith(etc: _split(value)));
            }),
            _buildMultiline(stringsKo['safetyNotes']!, _safety, (value) {
              _emit(widget.data.copyWith(safetyNotes: _split(value)));
            }),
            const SizedBox(height: 12),
            Text(stringsKo['grade']!),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: widget.data.grade.value.isEmpty
                  ? null
                  : widget.data.grade.value,
              items: const [
                DropdownMenuItem(value: 'A', child: Text('A')),
                DropdownMenuItem(value: 'B', child: Text('B')),
                DropdownMenuItem(value: 'C', child: Text('C')),
                DropdownMenuItem(value: 'D', child: Text('D')),
                DropdownMenuItem(value: 'E', child: Text('E')),
                DropdownMenuItem(value: 'F', child: Text('F')),
              ],
              onChanged: widget.enabled
                  ? (value) {
                      if (value == null) return;
                      _emit(
                        widget.data.copyWith(
                          grade: widget.data.grade.copyWith(value: value),
                        ),
                      );
                    }
                  : null,
              decoration: const InputDecoration(
                labelText: '등급',
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _gradeNote,
              label: '등급 설명',
              onChanged: (value) => _emit(
                widget.data.copyWith(
                  grade: widget.data.grade.copyWith(note: value),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildMultiline(stringsKo['investigatorOpinion']!, _opinion, (value) {
              _emit(widget.data.copyWith(investigatorOpinion: value));
            }, minLines: 4),
          ],
        ),
      ),
    );

    return Opacity(
      opacity: widget.enabled ? 1 : 0.7,
      child: card,
    );
  }

  Widget _buildMultiline(
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged, {
    int minLines = 3,
  }) {
    return _buildTextField(
      controller: controller,
      label: label,
      onChanged: (value) => onChanged(value),
      minLines: minLines,
      maxLines: minLines + 2,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    String? hint,
    int minLines = 1,
    int maxLines = 4,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        enabled: widget.enabled,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: widget.enabled ? onChanged : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }
}
