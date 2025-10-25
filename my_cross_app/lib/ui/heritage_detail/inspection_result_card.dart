import 'package:flutter/material.dart';

import '../../models/heritage_detail_models.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '주요 점검 결과',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Column(
              children: [
                for (int i = 0; i < _rows.length; i++) ...[
                  if (i > 0) _dividerLine(),
                  _tableRow(
                    _rows[i].$2,
                    _rows[i].$3,
                    _controllers[_rows[i].$1]!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Align(
                alignment: isMobile ? Alignment.center : Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ 주요 점검 결과가 저장되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('저장'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2A44),
                    minimumSize: isMobile
                        ? const Size(double.infinity, 44)
                        : const Size(120, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  Widget _tableRow(String title, String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1E2A44),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller,
              maxLines: 3,
              minLines: 3,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E2A44), width: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerLine() {
    return Container(
      height: 1,
      color: const Color(0xFFE5E7EB),
      margin: const EdgeInsets.symmetric(horizontal: 12),
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
