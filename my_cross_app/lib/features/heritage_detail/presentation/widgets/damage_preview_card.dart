import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:my_cross_app/core/widgets/optimized_image.dart';

/// Damage preview card with fixed 4:3 aspect ratio thumbnail
class DamageCardPreview extends StatelessWidget {
  const DamageCardPreview({
    super.key,
    required this.imageUrl,
    required this.detections,
    this.imageWidth,
    this.imageHeight,
    this.severityGrade,
    this.location,
    this.phenomenon,
    this.timestamp,
    this.onDelete,
  });

  final String imageUrl;
  final List<Map<String, dynamic>> detections;
  final double? imageWidth;
  final double? imageHeight;
  final String? severityGrade;
  final String? location;
  final String? phenomenon;
  final String? timestamp;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final boxes = _DamagePreviewBox.parseAll(detections);

    final card = Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed 4:3 aspect ratio
          AspectRatio(
            aspectRatio: 4 / 3,
            child: _ThumbnailPreview(
              imageUrl: imageUrl,
              boxes: boxes,
              originalWidth: imageWidth,
              originalHeight: imageHeight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location?.isNotEmpty == true ? location! : '위치 정보 없음',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  phenomenon?.isNotEmpty == true
                      ? phenomenon!
                      : '손상 현상 정보가 없습니다',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_graph,
                          size: 14,
                          color: boxes.isNotEmpty
                              ? const Color(0xFF4B6CB7)
                              : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '감지 ${boxes.length}건',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: boxes.isNotEmpty
                                ? const Color(0xFF4B6CB7)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    if (timestamp != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(timestamp!),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openFullscreenViewer(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              card,
              // Overlay badges on top
              if (severityGrade != null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _gradeColor(severityGrade!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      severityGrade!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (onDelete != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black.withOpacity(0.55),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onDelete,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF4CAF50);
      case 'B':
        return const Color(0xFF8BC34A);
      case 'C1':
        return const Color(0xFFFFC107);
      case 'C2':
        return const Color(0xFFFF9800);
      case 'D':
        return const Color(0xFFFF5722);
      case 'E':
        return const Color(0xFFF44336);
      case 'F':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return '오늘';
      } else if (difference.inDays == 1) {
        return '어제';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}일 전';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}주 전';
      } else {
        return '${date.month}/${date.day}';
      }
    } catch (e) {
      return timestamp;
    }
  }

  void _openFullscreenViewer(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => DamageFullscreenViewer(
        imageUrl: imageUrl,
        originalWidth: imageWidth,
        originalHeight: imageHeight,
        detections: detections,
        severityGrade: severityGrade,
        location: location,
        phenomenon: phenomenon,
      ),
    );
  }
}

/// Thumbnail preview with proper BoxFit.contain scaling
class _ThumbnailPreview extends StatelessWidget {
  const _ThumbnailPreview({
    required this.imageUrl,
    required this.boxes,
    required this.originalWidth,
    required this.originalHeight,
  });

  final String imageUrl;
  final List<_DamagePreviewBox> boxes;
  final double? originalWidth;
  final double? originalHeight;

  bool get _hasValidSize =>
      (originalWidth ?? 0) > 0 && (originalHeight ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final containerHeight = constraints.maxHeight;

        if (imageUrl.isEmpty || !_hasValidSize) {
          return Container(
            color: const Color(0xFFF3F4F6),
            child: const Center(
              child: Icon(Icons.image, size: 32, color: Color(0xFF9CA3AF)),
            ),
          );
        }

        // Calculate actual rendered image size with BoxFit.contain
        final fitted = painting.applyBoxFit(
          BoxFit.contain,
          Size(originalWidth!, originalHeight!),
          Size(containerWidth, containerHeight),
        );
        final renderedWidth = fitted.destination.width;
        final renderedHeight = fitted.destination.height;
        final dx = (containerWidth - renderedWidth) / 2;
        final dy = (containerHeight - renderedHeight) / 2;

        // Scale factors based on rendered image size
        final scaleX = renderedWidth / originalWidth!;
        final scaleY = renderedHeight / originalHeight!;

        return Container(
          color: const Color(0xFFF3F4F6),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            fit: StackFit.expand,
            children: [
              // Base image
              Positioned.fill(
                child: OptimizedImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  maxWidth: 1280,
                  maxHeight: 960,
                  placeholder: const _PreviewPlaceholder(),
                  errorWidget: const _PreviewPlaceholder(
                    icon: Icons.broken_image,
                  ),
                ),
              ),
              // Bounding boxes - positioned within rendered image area
              if (boxes.isNotEmpty)
                Positioned(
                  left: dx,
                  top: dy,
                  width: renderedWidth,
                  height: renderedHeight,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        for (final box in boxes)
                          Positioned(
                            left: box.left(scaleX),
                            top: box.top(scaleY),
                            width: box.width(scaleX),
                            height: box.height(scaleY),
                            child: _BoundingBoxDecoration(box: box),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({this.icon = Icons.image});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: Icon(icon, size: 32, color: const Color(0xFF9CA3AF)),
      ),
    );
  }
}

class _DamagePreviewBox {
  const _DamagePreviewBox({
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

  static List<_DamagePreviewBox> parseAll(
    List<Map<String, dynamic>> detections,
  ) {
    return detections
        .map(_DamagePreviewBox._fromRaw)
        .whereType<_DamagePreviewBox>()
        .toList(growable: false);
  }

  static _DamagePreviewBox? _fromRaw(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final bbox = raw['bbox'];
    if (bbox is! List || bbox.length != 4) return null;

    double? _numToDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final x1 = _numToDouble(bbox[0]);
    final y1 = _numToDouble(bbox[1]);
    final x2 = _numToDouble(bbox[2]);
    final y2 = _numToDouble(bbox[3]);
    if ([x1, y1, x2, y2].any((value) => value == null)) {
      return null;
    }

    final score = (_numToDouble(raw['score']) ?? 0).clamp(0.0, 1.0);
    final label = (raw['label']?.toString() ?? '').trim();
    return _DamagePreviewBox(
      x1: x1!,
      y1: y1!,
      x2: x2!,
      y2: y2!,
      label: label.isEmpty ? 'Detection' : label,
      score: score,
    );
  }

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
    if (normalizedLabel.contains('압괴') || normalizedLabel.contains('터짐')) {
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

  String get labelText =>
      '${label.isEmpty ? 'Detection' : label} '
      '${(score * 100).toStringAsFixed(1)}%';
}

class _BoundingBoxDecoration extends StatelessWidget {
  const _BoundingBoxDecoration({required this.box});

  final _DamagePreviewBox box;

  @override
  Widget build(BuildContext context) {
    final color = box.color;
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
          decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
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
                box.labelText,
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

/// Fullscreen viewer for damage survey images with bounding boxes
class DamageFullscreenViewer extends StatelessWidget {
  const DamageFullscreenViewer({
    super.key,
    required this.imageUrl,
    required this.detections,
    this.originalWidth,
    this.originalHeight,
    this.severityGrade,
    this.location,
    this.phenomenon,
  });

  final String imageUrl;
  final List<Map<String, dynamic>> detections;
  final double? originalWidth;
  final double? originalHeight;
  final String? severityGrade;
  final String? location;
  final String? phenomenon;

  @override
  Widget build(BuildContext context) {
    final boxes = _DamagePreviewBox.parseAll(detections);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.95),
        child: SafeArea(
          child: Column(
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (severityGrade != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _gradeColor(severityGrade!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          severityGrade!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      tooltip: '닫기',
                    ),
                  ],
                ),
              ),
              // Image viewer
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (imageUrl.isEmpty) {
                        return const Center(
                          child: Text(
                            '이미지를 불러올 수 없습니다',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }

                      final maxWidth = constraints.maxWidth * 0.9;
                      final maxHeight = constraints.maxHeight * 0.7;

                      if (originalWidth != null &&
                          originalHeight != null &&
                          originalWidth! > 0 &&
                          originalHeight! > 0) {
                        // Calculate rendered size with BoxFit.contain
                        final fitted = painting.applyBoxFit(
                          BoxFit.contain,
                          Size(originalWidth!, originalHeight!),
                          Size(maxWidth, maxHeight),
                        );
                        final renderedWidth = fitted.destination.width;
                        final renderedHeight = fitted.destination.height;
                        final scaleX = renderedWidth / originalWidth!;
                        final scaleY = renderedHeight / originalHeight!;

                        return Container(
                          width: renderedWidth,
                          height: renderedHeight,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              // Image
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: OptimizedImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                    maxWidth: 1920,
                                    maxHeight: 1080,
                                    errorWidget: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white,
                                        size: 64,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Bounding boxes
                              if (boxes.isNotEmpty)
                                Positioned.fill(
                                  child: ClipRect(
                                    child: Stack(
                                      children: [
                                        for (final box in boxes)
                                          Positioned(
                                            left: box.left(scaleX),
                                            top: box.top(scaleY),
                                            width: box.width(scaleX),
                                            height: box.height(scaleY),
                                            child: _FullscreenBoundingBox(
                                              box: box,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      } else {
                        // Fallback without scaling
                        return Container(
                          constraints: BoxConstraints(
                            maxWidth: maxWidth,
                            maxHeight: maxHeight,
                          ),
                          child: OptimizedImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            maxWidth: 1920,
                            maxHeight: 1080,
                            errorWidget: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              // Metadata section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (location != null && location!.isNotEmpty) ...[
                      _MetadataRow('위치', location!),
                      const SizedBox(height: 12),
                    ],
                    if (phenomenon != null && phenomenon!.isNotEmpty) ...[
                      _MetadataRow('손상 현상', phenomenon!),
                      const SizedBox(height: 12),
                    ],
                    _MetadataRow('감지된 손상', '${boxes.length}건'),
                    if (boxes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: boxes.map((box) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: box.color.withOpacity(0.2),
                              border: Border.all(color: box.color, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              box.labelText,
                              style: TextStyle(
                                color: box.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF4CAF50);
      case 'B':
        return const Color(0xFF8BC34A);
      case 'C1':
        return const Color(0xFFFFC107);
      case 'C2':
        return const Color(0xFFFF9800);
      case 'D':
        return const Color(0xFFFF5722);
      case 'E':
        return const Color(0xFFF44336);
      case 'F':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FullscreenBoundingBox extends StatelessWidget {
  const _FullscreenBoundingBox({required this.box});

  final _DamagePreviewBox box;

  @override
  Widget build(BuildContext context) {
    final color = box.color;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 4),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.95),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                box.labelText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
