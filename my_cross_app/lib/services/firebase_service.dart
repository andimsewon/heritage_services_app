import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  final _fs = FirebaseFirestore.instance;
  final _st = FirebaseStorage.instance;
  final _uuid = const Uuid();

  /// 사진 업로드 + 문서 생성
  /// [imageBytes]: JPEG/PNG 바이트
  /// [sizeGetter]: 이미지의 width/height를 미리 계산해서 전달(웹/모바일 처리 방식이 달라서 콜백 사용)
  Future<void> addPhoto({
    required String heritageId,
    required String title,
    required Uint8List imageBytes,
    required Future<ui.Size> Function() sizeGetter,
  }) async {
    final id = _uuid.v4();
    final path = 'heritages/$heritageId/photos/$id.jpg';

    // 1) Storage 업로드
    final task = await _st.ref(path).putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await task.ref.getDownloadURL();

    // 2) 메타데이터 (width/height 계산)
    final sz = await sizeGetter();
    final width = sz.width.toInt();
    final height = sz.height.toInt();

    // 3) Firestore 문서
    await _fs.collection('heritages').doc(heritageId)
        .collection('photos').doc(id)
        .set({
      'title': title,
      'url': url,
      'width': width,
      'height': height,
      'bytes': imageBytes.lengthInBytes,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 손상부 조사 결과 저장
  Future<void> addDamageSurvey({
    required String heritageId,
    required Uint8List imageBytes,
    required String imageUrl,
    required List<Map<String, dynamic>> detections, // label, score, x,y,w,h (0~1)
    String? severity,
    String? memo,
  }) async {
    final id = _uuid.v4();
    await _fs.collection('heritages').doc(heritageId)
        .collection('damage_surveys').doc(id)
        .set({
      'imageUrl': imageUrl,
      'detections': detections,
      'severity': severity,
      'memo': memo,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 스트림 (사진 리스트)
  Stream<QuerySnapshot<Map<String, dynamic>>> photosStream(String heritageId) {
    return _fs.collection('heritages').doc(heritageId)
        .collection('photos').orderBy('createdAt', descending: true).snapshots();
  }

  /// 스트림 (손상부 조사 리스트)
  Stream<QuerySnapshot<Map<String, dynamic>>> damageStream(String heritageId) {
    return _fs.collection('heritages').doc(heritageId)
        .collection('damage_surveys').orderBy('createdAt', descending: true).snapshots();
  }
}
