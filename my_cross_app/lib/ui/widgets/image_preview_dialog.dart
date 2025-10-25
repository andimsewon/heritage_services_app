import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String meta;

  const ImagePreviewDialog({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.meta,
  });

  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'https' && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  String _getProxiedUrl(String originalUrl) {
    // Firebase Storage URL인 경우 프록시 서버를 통해 로드
    if (originalUrl.contains('firebasestorage.googleapis.com')) {
      // Env.proxyBase를 직접 사용하지 않고 하드코딩된 값 사용
      const proxyBase = 'http://localhost:8080';
      return '$proxyBase/image/proxy?url=${Uri.encodeComponent(originalUrl)}';
    }
    // 다른 URL은 그대로 사용
    return originalUrl;
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '이미지 로딩 실패',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'URL 확인 필요',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            // 이미지 영역
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: _isValidUrl(imageUrl)
                      ? InteractiveViewer(
                          panEnabled: true,
                          boundaryMargin: const EdgeInsets.all(20),
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: CachedNetworkImage(
                            imageUrl: _getProxiedUrl(imageUrl),
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey.shade300,
                              highlightColor: Colors.grey.shade100,
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              print('이미지 로딩 에러: $error');
                              print('프록시 URL: $url');
                              return _buildErrorWidget();
                            },
                          ),
                        )
                      : _buildErrorWidget(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void show(BuildContext context, {
    required String imageUrl,
    required String title,
    required String meta,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ImagePreviewDialog(
        imageUrl: imageUrl,
        title: title,
        meta: meta,
      ),
    );
  }
}
