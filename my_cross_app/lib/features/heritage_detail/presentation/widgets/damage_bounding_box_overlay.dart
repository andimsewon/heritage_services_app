import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' show applyBoxFit;

/// Renders AI bounding boxes on top of an image while respecting the
/// BoxFit that was used to draw the underlying bitmap.
class DamageBoundingBoxOverlay extends StatelessWidget {
  const DamageBoundingBoxOverlay({
    super.key,
    required this.child,
    required this.detections,
    required this.originalWidth,
    required this.originalHeight,
    this.fit = BoxFit.contain,
  });

  /// Image widget that should be displayed as the base layer.
  final Widget child;

  /// Raw detection maps that contain at least the `bbox`, `label`, and `score`.
  final List<Map<String, dynamic>> detections;

  /// Original pixel width of the image that produced [detections].
  final double? originalWidth;

  /// Original pixel height of the image that produced [detections].
  final double? originalHeight;

  /// Fit used by the base image. The same fit is applied when scaling boxes.
  final BoxFit fit;

  bool get _hasValidImageSize {
    return (originalWidth ?? 0) > 0 && (originalHeight ?? 0) > 0;
  }

  @override
  Widget build(BuildContext context) {
    final parsedDetections = detections
        .map(_DamageDetection.fromMap)
        .whereType<_DamageDetection>()
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure the base image fills the container
        final baseImage = SizedBox(
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity,
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : double.infinity,
          child: child,
        );

        final canRenderBoxes =
            _hasValidImageSize && parsedDetections.isNotEmpty;
        if (!canRenderBoxes) {
          return baseImage;
        }

        final containerWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : originalWidth!;
        final containerHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : originalHeight!;

        final fitted = applyBoxFit(
          fit,
          Size(originalWidth!, originalHeight!),
          Size(containerWidth, containerHeight),
        );
        final renderedWidth = fitted.destination.width;
        final renderedHeight = fitted.destination.height;
        final dx = (containerWidth - renderedWidth) / 2;
        final dy = (containerHeight - renderedHeight) / 2;
        final scaleX = renderedWidth / originalWidth!;
        final scaleY = renderedHeight / originalHeight!;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            // Base image layer - must be visible
            Positioned.fill(
              child: baseImage,
            ),
            // Bounding boxes overlay - clipped to image rendering area
            Positioned(
              left: dx,
              top: dy,
              width: renderedWidth,
              height: renderedHeight,
              child: ClipRect(
                child: Stack(
                  children: [
                    for (final detection in parsedDetections)
                      Positioned(
                        left: detection.left(scaleX),
                        top: detection.top(scaleY),
                        width: detection.width(scaleX),
                        height: detection.height(scaleY),
                        child: _BoundingBoxDecoration(detection: detection),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DamageDetection {
  const _DamageDetection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.label,
    required this.score,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String label;
  final double score;

  double get _minX => math.min(x1, x2);
  double get _minY => math.min(y1, y2);
  double get _width => (x2 - x1).abs();
  double get _height => (y2 - y1).abs();

  double left(double scaleX) => _minX * scaleX;
  double top(double scaleY) => _minY * scaleY;
  double width(double scaleX) => math.max(1, _width * scaleX);
  double height(double scaleY) => math.max(1, _height * scaleY);

  Color get color {
    final normalizedLabel = label.toLowerCase();
    if (normalizedLabel.contains('갈램') || normalizedLabel.contains('갈래')) {
      return const Color(0xFFFF6B6B);
    }
    if (normalizedLabel.contains('균열')) {
      return const Color(0xFFFFA500);
    }
    if (normalizedLabel.contains('부후')) {
      return const Color(0xFF8B4513);
    }
    if (normalizedLabel.contains('압괴') ||
        normalizedLabel.contains('터짐')) {
      return const Color(0xFFDC143C);
    }
    if (score >= 0.7) {
      return const Color(0xFFFF0000);
    }
    if (score >= 0.5) {
      return const Color(0xFFFF6B6B);
    }
    return const Color(0xFFFFA500);
  }

  static _DamageDetection? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final bbox = raw['bbox'];
    if (bbox is! List || bbox.length != 4) return null;

    double? _safeToDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final x1 = _safeToDouble(bbox[0]);
    final y1 = _safeToDouble(bbox[1]);
    final x2 = _safeToDouble(bbox[2]);
    final y2 = _safeToDouble(bbox[3]);
    if ([x1, y1, x2, y2].any((element) => element == null)) {
      return null;
    }

    final score = _safeToDouble(raw['score']) ?? 0.0;
    final label = (raw['label']?.toString() ?? '').trim();

    return _DamageDetection(
      x1: x1!,
      y1: y1!,
      x2: x2!,
      y2: y2!,
      label: label.isEmpty ? 'Detection' : label,
      score: score.clamp(0.0, 1.0),
    );
  }
}

class _BoundingBoxDecoration extends StatelessWidget {
  const _BoundingBoxDecoration({required this.detection});

  final _DamageDetection detection;

  @override
  Widget build(BuildContext context) {
    final color = detection.color;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 3),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.9),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${detection.label} ${(detection.score * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
