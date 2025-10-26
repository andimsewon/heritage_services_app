import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';

class LocationStatusCard extends StatefulWidget {
  final String heritageId;
  final String heritageName;

  const LocationStatusCard({
    super.key,
    required this.heritageId,
    required this.heritageName,
  });

  @override
  State<LocationStatusCard> createState() => _LocationStatusCardState();
}

class LocationPhoto {
  final String? docId; // Firestore 문서 ID (기존 사진)
  final String? imageUrl; // Firebase Storage URL (기존 사진)
  final XFile? imageFile; // 로컬 파일 (새 사진)
  final TextEditingController descriptionController;
  bool isUploading; // 업로드 중인지 표시

  LocationPhoto({
    this.docId,
    this.imageUrl,
    this.imageFile,
    String? initialDescription,
    this.isUploading = false,
  }) : descriptionController = TextEditingController(text: initialDescription ?? '');

  void dispose() {
    descriptionController.dispose();
  }

  bool get isExisting => docId != null && imageUrl != null;
  bool get isNew => imageFile != null;
}

class _LocationStatusCardState extends State<LocationStatusCard> {
  final List<LocationPhoto> _photos = [];
  final ImagePicker _picker = ImagePicker();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingPhotos();
  }

  /// Firestore에서 기존 사진들 불러오기
  Future<void> _loadExistingPhotos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('heritages')
          .doc(widget.heritageId)
          .collection('location_photos')
          .orderBy('timestamp', descending: false)
          .get();

      if (mounted) {
        setState(() {
          _photos.clear();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            _photos.add(
              LocationPhoto(
                docId: doc.id,
                imageUrl: data['url'] as String?,
                initialDescription: data['title'] as String? ?? '',
                isUploading: false,
              ),
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('기존 사진 로드 실패: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 사진 선택 및 Firebase 업로드
  Future<void> _pickPhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (picked == null) return;

      // 새 사진을 목록에 추가 (업로딩 상태)
      final newPhoto = LocationPhoto(
        imageFile: picked,
        isUploading: true,
      );

      setState(() {
        _photos.add(newPhoto);
      });

      // Firebase Storage에 업로드
      final bytes = await picked.readAsBytes();
      final imageUrl = await _firebaseService.uploadImage(
        heritageId: widget.heritageId,
        folder: 'location_photos',
        bytes: bytes,
      );

      // Firestore에 문서 생성
      final docRef = await FirebaseFirestore.instance
          .collection('heritages')
          .doc(widget.heritageId)
          .collection('location_photos')
          .add({
        'url': imageUrl,
        'title': '',
        'heritageName': widget.heritageName,
        'bytes': bytes.length,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 업로드 완료 후 상태 업데이트
      if (mounted) {
        setState(() {
          final index = _photos.indexOf(newPhoto);
          if (index != -1) {
            _photos[index] = LocationPhoto(
              docId: docRef.id,
              imageUrl: imageUrl,
              imageFile: picked,
              isUploading: false,
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 업로드되었습니다')),
        );
      }
    } catch (e) {
      debugPrint('사진 업로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 업로드 실패: $e')),
        );
        // 업로드 실패한 사진 제거
        setState(() {
          _photos.removeWhere((p) => p.isUploading);
        });
      }
    }
  }

  /// 사진 삭제 (Firebase Storage + Firestore)
  Future<void> _removePhoto(int index) async {
    final photo = _photos[index];

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Firestore에서 삭제
      if (photo.docId != null && photo.imageUrl != null) {
        await _firebaseService.deletePhoto(
          heritageId: widget.heritageId,
          docId: photo.docId!,
          url: photo.imageUrl!,
          folder: 'location_photos',
        );
      }

      if (mounted) {
        setState(() {
          _photos[index].dispose();
          _photos.removeAt(index);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 삭제되었습니다')),
        );
      }
    } catch (e) {
      debugPrint('사진 삭제 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 삭제 실패: $e')),
        );
      }
    }
  }

  /// 사진 설명 업데이트 (Firestore)
  Future<void> _updateDescription(LocationPhoto photo) async {
    if (photo.docId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('heritages')
          .doc(widget.heritageId)
          .collection('location_photos')
          .doc(photo.docId)
          .update({
        'title': photo.descriptionController.text,
      });
    } catch (e) {
      debugPrint('설명 업데이트 실패: $e');
    }
  }

  @override
  void dispose() {
    for (var photo in _photos) {
      photo.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 제목 행
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '위치 현황',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF111827),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('사진 등록'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2A44),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 빨간색 안내문
          const Text(
            '* 위치현황은 위성사진, 지형도면, 배치도 등 위치 정보 관련 자료를 말함',
            style: TextStyle(
              fontSize: 13,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // 가로 스크롤 사진 영역
          if (_isLoading)
            const SizedBox(
              height: 230,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            SizedBox(
              height: 230,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 기존 사진들
                    for (int i = 0; i < _photos.length; i++) ...[
                      _buildPhotoCard(_photos[i], index: i),
                      const SizedBox(width: 12),
                    ],
                    // 추가용 빈 박스
                    _buildAddCard(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(LocationPhoto photo, {required int index}) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        color: const Color(0xFFF8F9FB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 사진 영역
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: photo.isUploading
                    ? Container(
                        width: 200,
                        height: 150,
                        color: const Color(0xFFF3F4F6),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(strokeWidth: 2),
                              SizedBox(height: 8),
                              Text(
                                '업로드 중...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : photo.isExisting
                        ? Image.network(
                            photo.imageUrl!,
                            width: 200,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 150,
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Color(0xFF9CA3AF),
                                ),
                              );
                            },
                          )
                        : FutureBuilder<Uint8List>(
                            future: photo.imageFile!
                                .readAsBytes()
                                .then((bytes) => Uint8List.fromList(bytes)),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  width: 200,
                                  height: 150,
                                  fit: BoxFit.cover,
                                );
                              } else {
                                return Container(
                                  width: 200,
                                  height: 150,
                                  color: const Color(0xFFF3F4F6),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
              ),
              // 삭제 버튼
              if (!photo.isUploading)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => _removePhoto(index),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // 설명 입력란
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: photo.descriptionController,
              enabled: !photo.isUploading,
              decoration: InputDecoration(
                hintText: '사진 설명 입력',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E2A44),
                    width: 1.2,
                  ),
                ),
              ),
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => _updateDescription(photo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 200,
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFD0D0D0),
            style: BorderStyle.solid,
          ),
          color: const Color(0xFFF2F4F7),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 8),
            Text(
              '사진 등록',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
