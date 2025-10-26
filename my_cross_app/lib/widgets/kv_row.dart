import 'package:flutter/material.dart';

/// Simple labeled row widget for key-value pairs
class KeyValueRow extends StatelessWidget {
  final String title;
  final Widget value;
  final bool enabled;
  final EdgeInsets? padding;

  const KeyValueRow({
    super.key,
    required this.title,
    required this.value,
    this.enabled = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Opacity(
              opacity: enabled ? 1.0 : 0.6,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}