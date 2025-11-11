import 'package:flutter/material.dart';

/// Switch + numeric count input row widget
class BoolCountRow extends StatelessWidget {
  final String label;
  final bool value;
  final int count;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final ValueChanged<int>? onCountChanged;
  final EdgeInsets? padding;

  const BoolCountRow({
    super.key,
    required this.label,
    required this.value,
    required this.count,
    this.enabled = true,
    this.onChanged,
    this.onCountChanged,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: count.toString(),
              enabled: enabled && value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onChanged: enabled && value
                  ? (value) {
                      final newCount = int.tryParse(value) ?? 0;
                      onCountChanged?.call(newCount);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}