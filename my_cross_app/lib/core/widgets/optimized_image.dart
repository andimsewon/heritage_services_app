// lib/widgets/optimized_image.dart
// 최적화된 이미지 위젯

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_cross_app/core/utils/image_url_helper.dart';
import 'package:visibility_detector/visibility_detector.dart';

class OptimizedImage extends StatefulWidget {
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
  final bool enableLazyLoading;
  final bool enableProxyOptimization;
  final int? proxyImageQuality;
  final double visibilityThreshold;
  final Duration lazyLoadDebounce;

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
    this.enableLazyLoading = true,
    this.enableProxyOptimization = true,
    this.proxyImageQuality,
    this.visibilityThreshold = 0.2,
    this.lazyLoadDebounce = const Duration(milliseconds: 120),
  });

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage>
    with AutomaticKeepAliveClientMixin {
  static bool _visibilityIntervalConfigured = false;

  bool _shouldLoadImage = false;
  Timer? _visibilityDebounceTimer;

  @override
  void initState() {
    super.initState();
    if (!_visibilityIntervalConfigured) {
      VisibilityDetectorController.instance.updateInterval = const Duration(
        milliseconds: 120,
      );
      _visibilityIntervalConfigured = true;
    }
    _shouldLoadImage = !widget.enableLazyLoading;
  }

  @override
  void dispose() {
    _visibilityDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final shouldShowImage = _shouldLoadImage || !widget.enableLazyLoading;
    final placeholder = widget.placeholder ?? _buildSkeletonPlaceholder();
    final Widget displayWidget = shouldShowImage
        ? _buildCachedNetworkImage(context)
        : placeholder;

    if (!widget.enableLazyLoading) {
      return displayWidget;
    }

    return VisibilityDetector(
      key: _detectorKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<bool>(shouldShowImage),
          child: displayWidget,
        ),
      ),
    );
  }

  Key get _detectorKey => ValueKey<String>(
    'optimized-image-${widget.imageUrl.hashCode}-${widget.width ?? 'w'}-${widget.height ?? 'h'}',
  );

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!widget.enableLazyLoading || _shouldLoadImage) return;

    final threshold = widget.visibilityThreshold.clamp(0.05, 1.0);
    if (info.visibleFraction >= threshold) {
      if (widget.lazyLoadDebounce <= Duration.zero) {
        _markReadyToLoad();
      } else {
        _visibilityDebounceTimer?.cancel();
        _visibilityDebounceTimer = Timer(
          widget.lazyLoadDebounce,
          _markReadyToLoad,
        );
      }
    } else {
      _visibilityDebounceTimer?.cancel();
    }
  }

  void _markReadyToLoad() {
    if (!mounted || _shouldLoadImage) return;
    setState(() => _shouldLoadImage = true);
  }

  Widget _buildCachedNetworkImage(BuildContext context) {
    final sanitizedUrl = widget.imageUrl.trim();
    if (sanitizedUrl.isEmpty) {
      return widget.errorWidget ?? _buildErrorWidget();
    }
    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = (mediaQuery?.devicePixelRatio ?? 1.0).clamp(
      1.0,
      kIsWeb ? 2.5 : 3.0,
    );

    // 웹 환경에서는 더 작은 크기로 메모리 사용량 감소 및 로딩 속도 향상
    final baseCacheWidth = widget.maxWidth ?? (widget.width?.toInt() ?? 1200);
    final baseCacheHeight =
        widget.maxHeight ?? (widget.height?.toInt() ?? 1200);

    final memCacheWidth = kIsWeb
        ? math.min(baseCacheWidth, 600)  // 800 -> 600으로 감소
        : math.min(baseCacheWidth, 1200);
    final memCacheHeight = kIsWeb
        ? math.min(baseCacheHeight, 600)  // 800 -> 600으로 감소
        : math.min(baseCacheHeight, 1200);

    const minDecodedDimension = 120;
    // 웹 환경에서는 디스크 캐시 크기도 줄여서 로딩 속도 향상
    final diskCacheCap = kIsWeb ? 1200 : 2200;  // 1600 -> 1200으로 감소
    final pixelAwareWidth = math.max(
      minDecodedDimension,
      math.min(diskCacheCap, (memCacheWidth * devicePixelRatio).round()),
    );
    final pixelAwareHeight = math.max(
      minDecodedDimension,
      math.min(diskCacheCap, (memCacheHeight * devicePixelRatio).round()),
    );

    // 웹 환경에서는 더 낮은 품질로 빠른 로딩
    final defaultQuality = kIsWeb ? 65 : 82;
    final optimizedUrl = widget.enableProxyOptimization
        ? ImageUrlHelper.buildOptimizedUrl(
            sanitizedUrl,
            maxWidth: pixelAwareWidth,
            maxHeight: pixelAwareHeight,
            quality: widget.proxyImageQuality ?? defaultQuality,
          )
        : sanitizedUrl;

    final resolvedFadeDuration = kIsWeb
        ? const Duration(milliseconds: 100)
        : widget.fadeInDuration;

    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: widget.enableMemoryCache ? memCacheWidth : null,
      memCacheHeight: widget.enableMemoryCache ? memCacheHeight : null,
      maxWidthDiskCache: pixelAwareWidth,
      maxHeightDiskCache: pixelAwareHeight,
      fadeInDuration: resolvedFadeDuration,
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (context, url) =>
          widget.placeholder ?? _buildSkeletonPlaceholder(),
      errorWidget: (context, url, error) =>
          widget.errorWidget ?? _buildErrorWidget(),
      imageBuilder: (context, imageProvider) {
        return ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
          child: Image(
            image: imageProvider,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: resolvedFadeDuration,
                curve: Curves.easeOut,
                child: child,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildSkeletonPlaceholder();
            },
          ),
        );
      },
      httpHeaders: const {
        'Cache-Control': 'max-age=31536000, public',
        'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
      },
      useOldImageOnUrlChange: true,
      cacheKey: optimizedUrl,  // 명시적 캐시 키 설정
      errorListener: (exception) {
        debugPrint('이미지 로딩 오류: $exception');
      },
    );
  }

  Widget _buildSkeletonPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: widget.borderRadius,
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0x990071E3)),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: widget.borderRadius,
      ),
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
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

class LazyImageLoader extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return OptimizedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder,
      enableLazyLoading: loadOnVisible,
    );
  }
}
