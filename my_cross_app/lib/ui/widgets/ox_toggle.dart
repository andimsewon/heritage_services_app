import 'package:flutter/material.dart';

import '../../theme.dart';

class OxToggle extends StatelessWidget {
  const OxToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = value
        ? AppTheme.primaryBlue.withValues(alpha: 0.12)
        : null;
    final foreground = value ? AppTheme.primaryBlue : colorScheme.onSurface;

    return Semantics(
      label: label,
      toggled: value,
      button: true,
      child: ChoiceChip(
        label: Text(value ? 'O' : 'X'),
        selected: value,
        showCheckmark: false,
        onSelected: (_) => onChanged(!value),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: foreground),
        selectedColor: background,
        side: BorderSide(color: AppTheme.tableDivider.withValues(alpha: 0.7)),
      ),
    );
  }
}
