import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_cross_app/core/widgets/optimized_image.dart';
import 'package:my_cross_app/core/services/firebase_service.dart';
import 'package:my_cross_app/core/services/image_acquire.dart';

class LocationStatusCard extends StatelessWidget {
  const LocationStatusCard({
    super.key,
    required this.heritageId,
    required this.heritageName,
    required this.photosStream,
    required this.onAddPhoto,
    required this.onPreview,
    required this.onDelete,
    required this.formatBytes,
  });

  final String heritageId;
  final String heritageName;
  final Stream<QuerySnapshot<Map<String, dynamic>>> photosStream;
  final VoidCallback onAddPhoto;
  final void Function(String url, String title) onPreview;
  final Future<void> Function(String docId, String url) onDelete;
  final String Function(num? bytes) formatBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 640 ? 16 : 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              Icon(Icons.place_outlined, color: Color(0xFF1E2A44), size: 20),
              Text(
                '위치 현황',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '위성사진, 배치도 등 위치 관련 자료를 등록하세요.',
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: MediaQuery.of(context).size.width < 640 ? 13 : 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: photosStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '등록된 사진이 없습니다.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: onAddPhoto,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            color: Color(0xFF2C3E8C),
                          ),
                          label: const Text(
                            '사진 등록',
                            style: TextStyle(color: Color(0xFF2C3E8C)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2C3E8C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final docs = snapshot.data!.docs
                    .where(
                      (doc) =>
                          ((doc.data())['url'] as String?)?.isNotEmpty ?? false,
                    )
                    .toList();
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '등록된 사진이 없습니다.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: onAddPhoto,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            color: Color(0xFF2C3E8C),
                          ),
                          label: const Text(
                            '사진 등록',
                            style: TextStyle(color: Color(0xFF2C3E8C)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2C3E8C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    // 사진 등록 버튼 (항상 표시)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Wrap(
                        alignment: MediaQuery.of(context).size.width < 640
                            ? WrapAlignment.start
                            : WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onAddPhoto,
                            icon: const Icon(
                              Icons.add_a_photo,
                              color: Color(0xFF2C3E8C),
                              size: 18,
                            ),
                            label: const Text(
                              '사진 추가',
                              style: TextStyle(color: Color(0xFF2C3E8C)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2C3E8C)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 사진 목록 - HeritagePhotoSection과 동일한 구조
                    Container(
                      height: 200, // 고정 높이
                      width: double.infinity, // 전체 너비 사용
                      child: ClipRect(
                        // 오버플로우 완전 차단
                        child: ScrollConfiguration(
                          behavior: const MaterialScrollBehavior(),
                          child: ListView.builder(
                            primary: false,
                            physics: const BouncingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            itemCount: docs.length,
                            itemBuilder: (_, index) {
                              final data = docs[index].data();
                              final title = (data['title'] as String?) ?? '';
                              final url = (data['url'] as String?) ?? '';
                              final meta =
                                  '${data['width'] ?? '?'}x${data['height'] ?? '?'} • ${formatBytes(data['bytes'] as num?)}';
                              return Container(
                                margin: EdgeInsets.only(
                                  left: index == 0 ? 12 : 8,
                                  right: index == docs.length - 1 ? 12 : 0,
                                ),
                                child: _PhotoCard(
                                  title: title,
                                  url: url,
                                  meta: meta,
                                  onPreview: () => onPreview(url, title),
                                  onDelete: () => onDelete(docs[index].id, url),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _PhotoCard({
    required String title,
    required String url,
    required String meta,
    required VoidCallback onPreview,
    required VoidCallback onDelete,
  }) {
    return Container(
      width: 150, // HeritagePhotoSection과 동일한 크기
      height: 180, // 고정 높이로 일관성 확보
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // AspectRatio 대신 Expanded 사용
            flex: 3, // 3:2 비율로 조정
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  OptimizedImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.8),
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPreview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3E66FB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('미리보기', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
