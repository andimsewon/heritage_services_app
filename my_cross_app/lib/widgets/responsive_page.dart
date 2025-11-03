// lib/widgets/responsive_page.dart
// Responsive wrapper for detail pages to ensure content renders at all viewport widths

import 'package:flutter/material.dart';

/// A responsive page wrapper that centers content with a max width
/// and ensures it renders correctly at all viewport sizes/zooms.
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: padding,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

