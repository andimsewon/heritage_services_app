import 'package:flutter/material.dart';

import '../../models/heritage_detail_models.dart';
import '../../theme.dart';
import '../widgets/section_title.dart';

class InspectionResultCard extends StatefulWidget {
  const InspectionResultCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final InspectionResult value;
  final ValueChanged<InspectionResult> onChanged;

  @override
  State<InspectionResultCard> createState() => _InspectionResultCardState();
}

class _InspectionResultCardState extends State<InspectionResultCard> {
  static const _rows = [
    ('foundation', '기단부', '예: 기초, 기둥 등 구조 부재 점검 결과'),
    ('wall', '축부(벽체부)', '예: 벽체 균열, 박락 등 조사 내용'),
    ('roof', '지붕부', '예: 지붕재 손상, 누수 관찰 결과'),
  ];

  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final (key, _, __) in _rows)
        key: TextEditingController(text: _valueFor(key)),
    };
    for (final entry in _controllers.entries) {
      entry.value.addListener(() => _handleChanged(entry.key));
    }
  }

  @override
  void didUpdateWidget(covariant InspectionResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final entry in _controllers.entries) {
      final key = entry.key;
      final controller = entry.value;
      final newValue = _valueFor(key);
      if (controller.text != newValue) {
        controller.text = newValue;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = TableBorder(
      horizontalInside: BorderSide(color: AppTheme.tableDivider),
      verticalInside: BorderSide(color: AppTheme.tableDivider),
      top: BorderSide(color: AppTheme.tableDivider),
      bottom: BorderSide(color: AppTheme.tableDivider),
      left: BorderSide(color: AppTheme.tableDivider),
      right: BorderSide(color: AppTheme.tableDivider),
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: AppTheme.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: AppTheme.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              title: '주요 점검 결과',
              trailing: FilledButton.icon(
                onPressed: () {
                  // TODO: Connect to Firestore/REST persistence layer.
                },
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('저장'),
              ),
            ),
            const SizedBox(height: 16),
            Table(
              border: border,
              columnWidths: const {
                0: FixedColumnWidth(130),
                1: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    color: AppTheme.tableHeaderBackground,
                  ),
                  children: [
                    _HeaderCell(theme: theme, label: '분류'),
                    _HeaderCell(theme: theme, label: '내용'),
                  ],
                ),
                for (final (key, label, placeholder) in _rows)
                  TableRow(
                    decoration: const BoxDecoration(color: Colors.white),
                    children: [
                      _LabelCell(text: label),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: TextFormField(
                          controller: _controllers[key],
                          maxLines: 4,
                          minLines: 3,
                          decoration: InputDecoration(
                            isDense: false,
                            hintText: placeholder,
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _valueFor(String key) {
    switch (key) {
      case 'foundation':
        return widget.value.foundation;
      case 'wall':
        return widget.value.wall;
      case 'roof':
        return widget.value.roof;
    }
    return '';
  }

  void _handleChanged(String key) {
    final controller = _controllers[key];
    if (controller == null) return;
    final updated = widget.value.copyWith(
      foundation: key == 'foundation'
          ? controller.text
          : widget.value.foundation,
      wall: key == 'wall' ? controller.text : widget.value.wall,
      roof: key == 'roof' ? controller.text : widget.value.roof,
    );
    widget.onChanged(updated);
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.theme, required this.label});

  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LabelCell extends StatelessWidget {
  const _LabelCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.tableHeaderBackground.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
