import 'package:my_cross_app/core/config/env.dart';

class ImageUrlHelper {
  const ImageUrlHelper._();

  /// Returns an optimized image URL that routes Firebase Storage images through
  /// the backend proxy so the file can be resized/compressed before delivery.
  static String buildOptimizedUrl(
    String originalUrl, {
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) {
    if (originalUrl.isEmpty) return originalUrl;
    final uri = Uri.tryParse(originalUrl);
    if (uri == null) return originalUrl;

    if (_isAlreadyProxied(uri)) {
      return _updateExistingProxy(uri, maxWidth, maxHeight, quality);
    }

    if (!_isFirebaseStorageUri(uri)) {
      return originalUrl;
    }

    return _buildProxyUrl(
      originalUrl,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
  }

  static bool _isFirebaseStorageUri(Uri uri) {
    return uri.host.toLowerCase().contains('firebasestorage.googleapis.com');
  }

  static bool _isAlreadyProxied(Uri uri) {
    return uri.path.contains('/image/proxy');
  }

  static String _buildProxyUrl(
    String originalUrl, {
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) {
    final normalizedBase = _normalizeBase(Env.proxyBase);
    final proxyPath = '$normalizedBase/image/proxy';
    final query = Uri(
      queryParameters: <String, String>{
        'url': originalUrl,
        if (_isValidDimension(maxWidth)) 'maxWidth': '$maxWidth',
        if (_isValidDimension(maxHeight)) 'maxHeight': '$maxHeight',
        if (_isValidQuality(quality)) 'quality': '$quality',
      },
    ).query;

    return query.isEmpty ? proxyPath : '$proxyPath?$query';
  }

  static String _updateExistingProxy(
    Uri uri,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  ) {
    final params = Map<String, String>.from(uri.queryParameters);

    void updateDimension(String key, int? value) {
      if (!_isValidDimension(value)) return;
      final existing = int.tryParse(params[key] ?? '');
      if (existing == null || value! < existing) {
        params[key] = '$value';
      }
    }

    updateDimension('maxWidth', maxWidth);
    updateDimension('maxHeight', maxHeight);

    if (_isValidQuality(quality)) {
      final existingQuality = int.tryParse(params['quality'] ?? '');
      if (existingQuality == null || quality! < existingQuality) {
        params['quality'] = '$quality';
      }
    }

    final updatedUri = uri.replace(queryParameters: params);
    return updatedUri.toString();
  }

  static String _normalizeBase(String base) {
    if (base.isEmpty) return '';
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  static bool _isValidDimension(int? value) {
    if (value == null) return false;
    return value > 0;
  }

  static bool _isValidQuality(int? value) {
    if (value == null) return false;
    return value >= 40 && value <= 95;
  }
}
