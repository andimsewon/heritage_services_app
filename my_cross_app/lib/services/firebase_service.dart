// lib/services/firebase_service.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  final _fs = FirebaseFirestore.instance;
  final _st = FirebaseStorage.instance;

  /// 문화유산 사진 업로드 (현황/조사 공용)
  /// folder: 'photos' | 'damage_surveys'
  Future<String> uploadImage({
    required String heritageId,
    required String folder,
    required Uint8List bytes,
  }) async {
    final id = const Uuid().v4();
    final ref = _st.ref().child('heritages/$heritageId/$folder/$id.jpg');

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  /// 현황 사진 문서 생성
  Future<void> addPhoto({
    required String heritageId,
    required String heritageName,
    required String title,
    required Uint8List imageBytes,
    required Future<ui.Size> Function() sizeGetter,
    String folder = 'photos',
  }) async {
    final url = await uploadImage(
      heritageId: heritageId,
      folder: folder,
      bytes: imageBytes,
    );
    final size = await sizeGetter();

    final col = _fs.collection('heritages').doc(heritageId).collection(folder);
    final id = const Uuid().v4();
    await col.doc(id).set({
      'url': url,
      'title': title,
      'heritageName': heritageName,
      'width': size.width,
      'height': size.height,
      'bytes': imageBytes.length,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// 손상부 조사 문서 생성 (AI 결과 포함)
  Future<void> addDamageSurvey({
    required String heritageId,
    required String heritageName,
    required String imageUrl,
    required List<Map<String, dynamic>> detections,
    String? desc,
    String? location, // 손상 위치
    String? phenomenon, // 손상 현상
    String? inspectorOpinion, // 조사자 의견
    String? severityGrade, // A~F
    Map<String, dynamic>? detailInputs, // 심화조사 입력값
  }) async {
    final col = _fs
        .collection('heritages')
        .doc(heritageId)
        .collection('damage_surveys');
    final id = const Uuid().v4();
    await col.doc(id).set({
      'imageUrl': imageUrl,
      'detections': detections,
      'heritageName': heritageName,
      'desc': desc ?? '손상부 조사',
      if (location != null) 'location': location,
      if (phenomenon != null) 'phenomenon': phenomenon,
      if (inspectorOpinion != null) 'inspectorOpinion': inspectorOpinion,
      if (severityGrade != null) 'severityGrade': severityGrade,
      if (detailInputs != null) 'detailInputs': detailInputs,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// 현황 사진 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> photosStream(String heritageId) {
    return _fs
        .collection('heritages')
        .doc(heritageId)
        .collection('photos')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// 손상부 조사 스트림 (최신 먼저)
  Stream<QuerySnapshot<Map<String, dynamic>>> damageStream(String heritageId) {
    return _fs
        .collection('heritages')
        .doc(heritageId)
        .collection('damage_surveys')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
