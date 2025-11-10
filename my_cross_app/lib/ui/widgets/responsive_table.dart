import 'package:flutter/material.dart';

/// Wraps wide tabular content so that it keeps a readable minimum width on
/// smaller viewports. When the available width drops below [minWidth], the
/// table becomes horizontally scrollable instead of shrinking until text wraps
/// per character.
class ResponsiveTable extends StatelessWidget {
  const ResponsiveTable({
    super.key,
    required this.child,
    this.minWidth = 900,
    this.controller,
  });

  final Widget child;
  final double minWidth;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        if (maxWidth.isFinite && maxWidth < minWidth) {
          return Scrollbar(
            controller: controller,
            thumbVisibility: true,
            thickness: 8,
            radius: const Radius.circular(12),
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 4),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: child,
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
