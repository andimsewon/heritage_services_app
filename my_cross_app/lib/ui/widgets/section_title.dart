import 'package:flutter/material.dart';

import '../../theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Container(
      padding: AppTheme.sectionTitlePadding,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(width: 4, color: AppTheme.sectionBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: textStyle)),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
