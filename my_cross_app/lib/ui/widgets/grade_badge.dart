import 'package:flutter/material.dart';

import '../../theme.dart';

class GradeBadge extends StatelessWidget {
  const GradeBadge({super.key, required this.grade, this.size = 48});

  final String grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.gradeColors[grade] ?? Colors.grey;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Text(
        grade,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
