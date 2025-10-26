import 'package:flutter/material.dart';

class BoolCountRow extends StatelessWidget {
  const BoolCountRow({
    super.key,
    required this.label,
    required this.value,
    required this.count,
    this.enabled = true,
    this.countLabel = '수량',
    this.onChanged,
    this.onCountChanged,
  });

  final String label;
  final bool value;
  final int count;
  final bool enabled;
  final String countLabel;
  final ValueChanged<bool>? onChanged;
  final ValueChanged<int>? onCountChanged;

  @override
  Widget build(BuildContext context) {
    final canToggle = enabled && onChanged != null;
    final canEditCount = enabled && value && onCountChanged != null;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: canToggle ? onChanged : null,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextFormField(
                key: ValueKey('count-$label-$count-$enabled'),
                enabled: canEditCount,
                initialValue: count.toString(),
                onChanged: canEditCount
                    ? (raw) {
                        final parsed = int.tryParse(raw.trim());
                        if (parsed != null) {
                          onCountChanged?.call(parsed);
                        }
                      }
                    : null,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: countLabel,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
