import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft gradient background with subtle glow blobs to make primary screens feel
/// less flat. Wrap any scrollable content with this widget to inherit the
/// ambient backdrop without duplicating decoration code in each screen.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, this.child, this.padding, this.gradient});

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final resolvedGradient =
        gradient ??
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9FBFF), Color(0xFFF1F4FB), Color(0xFFE8EFFA)],
        );

    return DecoratedBox(
      decoration: BoxDecoration(gradient: resolvedGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _GlowBlob(
            size: 240,
            color: Color(0xFFB3C9FF),
            offset: Offset(160, -60),
          ),
          const _GlowBlob(
            size: 320,
            color: Color(0xFFA8E8FF),
            offset: Offset(-120, -20),
          ),
          const _GlowBlob(
            size: 280,
            color: Color(0xFFFFE7C4),
            offset: Offset(120, 260),
          ),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.size,
    required this.color,
    required this.offset,
  });

  final double size;
  final Color color;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: math.pi / 6,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size),
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.45),
                  color.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
