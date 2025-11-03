// lib/widgets/optimized_image.dart
// 최적화된 이미지 위젯

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final int? maxWidth;
  final int? maxHeight;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableMemoryCache;
  final Duration fadeInDuration;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    // 메모리 캐시 크기 계산 (maxWidth/maxHeight 우선, 없으면 width/height 사용)
    final memCacheWidth = maxWidth ?? width?.toInt();
    final memCacheHeight = maxHeight ?? height?.toInt();
    
    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidth ?? 1920, // 디스크 캐시 최대 크기
      maxHeightDiskCache: maxHeight ?? 1920,
      fadeInDuration: fadeInDuration,
      placeholder: (context, url) => placeholder ?? _buildSkeletonPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      imageBuilder: (context, imageProvider) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image(
            image: imageProvider,
            width: width,
            height: height,
            fit: fit,
          ),
        );
      },
    );

    return imageWidget;
  }

  Widget _buildSkeletonPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}

class OptimizedImageList extends StatelessWidget {
  final List<String> imageUrls;
  final double itemWidth;
  final double itemHeight;
  final int crossAxisCount;
  final double spacing;
  final BorderRadius? borderRadius;

  const OptimizedImageList({
    super.key,
    required this.imageUrls,
    required this.itemWidth,
    required this.itemHeight,
    this.crossAxisCount = 2,
    this.spacing = 8.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: itemWidth / itemHeight,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        return OptimizedImage(
          imageUrl: imageUrls[index],
          width: itemWidth,
          height: itemHeight,
          borderRadius: borderRadius,
        );
      },
    );
  }
}

class LazyImageLoader extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final bool loadOnVisible;

  const LazyImageLoader({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.loadOnVisible = true,
  });

  @override
  State<LazyImageLoader> createState() => _LazyImageLoaderState();
}

class _LazyImageLoaderState extends State<LazyImageLoader> {
  bool _isVisible = false;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!widget.loadOnVisible) {
      _isVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible && widget.loadOnVisible) {
      return VisibilityDetector(
        key: Key(widget.imageUrl),
        onVisibilityChanged: (visibilityInfo) {
          if (visibilityInfo.visibleFraction > 0 && !_hasLoaded) {
            setState(() {
              _isVisible = true;
              _hasLoaded = true;
            });
          }
        },
        child: widget.placeholder ?? _buildPlaceholder(),
      );
    }

    return OptimizedImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      borderRadius: widget.borderRadius,
      placeholder: widget.placeholder,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: widget.borderRadius,
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}

// VisibilityDetector는 별도 패키지가 필요하므로 간단한 구현
class VisibilityDetector extends StatefulWidget {
  final Widget child;
  final ValueChanged<VisibilityInfo> onVisibilityChanged;

  const VisibilityDetector({
    super.key,
    required this.child,
    required this.onVisibilityChanged,
  });

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (mounted) {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        final screenSize = MediaQuery.of(context).size;
        
        final isVisible = position.dy < screenSize.height && 
                         position.dy + size.height > 0;
        
        widget.onVisibilityChanged(VisibilityInfo(
          visibleFraction: isVisible ? 1.0 : 0.0,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class VisibilityInfo {
  final double visibleFraction;
  
  const VisibilityInfo({
    required this.visibleFraction,
  });
}
