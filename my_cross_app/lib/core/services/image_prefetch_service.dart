import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:my_cross_app/core/utils/image_url_helper.dart';

class ImagePrefetchService {
  ImagePrefetchService._();

  static final ImagePrefetchService _instance = ImagePrefetchService._();
  factory ImagePrefetchService() => _instance;

  final BaseCacheManager _cacheManager = DefaultCacheManager();
  final Set<String> _inFlight = <String>{};

  void warmUp(
    List<String> urls, {
    int limit = 8,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) {
    if (urls.isEmpty) return;
    final targetLimit = limit.clamp(1, 20);
    unawaited(
      _prefetch(
        urls,
        limit: targetLimit,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      ),
    );
  }

  void warmUpSingle(
    String url, {
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) {
    warmUp(
      [url],
      limit: 1,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
  }

  Future<void> _prefetch(
    List<String> urls, {
    required int limit,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    final normalized = urls
        .map((url) => url.trim())
        .where((url) => url.startsWith('http'))
        .toList(growable: false);
    if (normalized.isEmpty) return;

    final targets = normalized.take(limit);

    for (final original in targets) {
      final optimized = ImageUrlHelper.buildOptimizedUrl(
        original,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality ?? (kIsWeb ? 58 : 78),
      );

      if (_inFlight.contains(optimized)) {
        continue;
      }

      if (await _isCached(optimized)) {
        continue;
      }

      _inFlight.add(optimized);
      try {
        await _cacheManager.downloadFile(
          optimized,
          key: optimized,
          force: false,
        );
      } catch (error) {
        debugPrint('⚠️ 이미지 프리페치 실패: $error');
      } finally {
        _inFlight.remove(optimized);
      }
    }
  }

  Future<bool> _isCached(String key) async {
    final cached = await _cacheManager.getFileFromCache(key);
    if (cached == null) return false;
    return cached.validTill.isAfter(DateTime.now());
  }
}
