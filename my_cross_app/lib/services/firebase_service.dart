// lib/services/firebase_service.dart
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Firebase Storage 업로드 오류 (Secure Context 문제)
class SecureContextException implements Exception {
  final String message;
  SecureContextException(this.message);

  @override
  String toString() => message;
}

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
    try {
      // HTTP 환경에서의 Service Worker 오류 처리
      if (kIsWeb) {
        debugPrint('🌐 웹 환경에서 이미지 업로드 시도...');
      }

      final id = const Uuid().v4();
      final ref = _st.ref().child('heritages/$heritageId/$folder/$id.jpg');

      // 웹 환경에서의 메타데이터 설정 개선
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000', // 1년 캐시
        customMetadata: {
          'heritageId': heritageId,
          'folder': folder,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);

      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        debugPrint('✅ 이미지 업로드 성공: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('Upload failed with state: ${uploadTask.state}');
      }
    } catch (e) {
      debugPrint('❌ Firebase Storage 업로드 실패: $e');

      // HTTP 환경에서의 Service Worker 오류인 경우 특별 처리
      if (kIsWeb &&
          (e.toString().contains('Service Worker') ||
              e.toString().contains('Secure Context') ||
              e.toString().contains('not secure'))) {
        debugPrint('⚠️ Secure Context 오류 감지 - HTTP 환경에서 실행 중입니다.');
        debugPrint('💡 해결 방법:');
        debugPrint('   1. HTTPS 환경에서 실행');
        debugPrint('   2. Firebase Hosting에 배포');
        debugPrint('   3. localhost에서 실행');

        throw SecureContextException(
            '이미지 업로드 실패: HTTPS 환경에서만 사용 가능합니다.\n'
            'Firebase Hosting에 배포하거나 HTTPS 환경에서 실행해주세요.');
      }

      throw Exception('Firebase Storage upload failed: $e');
    }
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
  /// 손상부 조사 문서 생성 (AI 결과 포함)
  Future<void> addDamageSurvey({
    required String heritageId,
    required String heritageName,
    required Uint8List imageBytes,   // ✅ bytes 직접 받도록 수정
    required List<Map<String, dynamic>> detections,
    String? desc,
    String? location,         // 손상 위치
    String? phenomenon,       // 손상 현상
    String? inspectorOpinion, // 조사자 의견
    String? severityGrade,    // A~F
    Map<String, dynamic>? detailInputs, // 심화조사 입력값
  }) async {
    // ✅ Firebase Storage 업로드 + 다운로드 URL 확보
    final imageUrl = await uploadImage(
      heritageId: heritageId,
      folder: 'damage_surveys',
      bytes: imageBytes,
    );

    final col = _fs
        .collection('heritages')
        .doc(heritageId)
        .collection('damage_surveys');
    final id = const Uuid().v4();

    await col.doc(id).set({
      'imageUrl': imageUrl,    // ✅ getDownloadURL() 반환값 저장
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

  /// 현황 사진 삭제 (문서 + 스토리지)
  Future<void> deletePhoto({
    required String heritageId,
    required String docId,
    required String url,
    String folder = 'photos',
  }) async {
    try {
      await _fs
          .collection('heritages')
          .doc(heritageId)
          .collection(folder)
          .doc(docId)
          .delete();
    } finally {
      try {
        await _st.refFromURL(url).delete();
      } catch (_) {}
    }
  }

  /// 손상부 조사 삭제 (문서 + 스토리지 이미지)
  Future<void> deleteDamageSurvey({
    required String heritageId,
    required String docId,
    required String imageUrl,
  }) async {
    try {
      await _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('damage_surveys')
          .doc(docId)
          .delete();
    } finally {
      try {
        await _st.refFromURL(imageUrl).delete();
      } catch (_) {}
    }
  }

  /// 사용자 추가 국가유산 생성
  Future<String> addCustomHeritage({
    required String kindCode,
    required String kindName,
    required String name,
    required String sojaeji,
    required String addr,
    // 기본 개요(선택)
    String? asdt,
    String? owner,
    String? admin,
    String? lcto,
    String? lcad,
    String? sourceRowId,
  }) async {
    final id = const Uuid().v4();
    final doc = _fs.collection('custom_heritages').doc(id);
    await doc.set({
      'id': 'custom_$id',
      'kindCode': kindCode,
      'kindName': kindName,
      'name': name,
      'sojaeji': sojaeji,
      'addr': addr,
      // 기본 개요 호환 키
      'ccmaName': kindName,
      'ccbaAsdt': asdt,
      'ccbaPoss': owner,
      'ccbaAdmin': admin,
      'ccbaLcto': lcto,
      'ccbaLcad': lcad,
      if (sourceRowId != null) 'sourceRowId': sourceRowId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    return id;
  }

  /// 사용자 추가 국가유산 수정
  Future<void> updateCustomHeritage({
    required String docId,
    required String kindCode,
    required String kindName,
    required String name,
    required String sojaeji,
    required String addr,
    String? asdt,
    String? owner,
    String? admin,
    String? lcto,
    String? lcad,
    String? sourceRowId,
  }) async {
    String? normalize(String? v) {
      if (v == null) return null;
      final trimmed = v.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final payload = {
      'kindCode': kindCode,
      'kindName': kindName,
      'name': name,
      'sojaeji': sojaeji,
      'addr': addr,
      'ccmaName': kindName,
      'ccbaAsdt': normalize(asdt),
      'ccbaPoss': normalize(owner),
      'ccbaAdmin': normalize(admin),
      'ccbaLcto': normalize(lcto),
      'ccbaLcad': normalize(lcad),
      if (sourceRowId != null) 'sourceRowId': sourceRowId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _fs.collection('custom_heritages').doc(docId).update(payload);
  }

  /// 사용자 추가 국가유산 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> customHeritagesStream() {
    return _fs
        .collection('custom_heritages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// 사용자 추가 국가유산 삭제
  Future<void> deleteCustomHeritage(String id) async {
    await _fs.collection('custom_heritages').doc(id).delete();
  }

  /// 전년도 손상부 조사 사진 로드
  /// 부재명, 방향, 번호, 위치로 검색하여 가장 최근 전년도 데이터 반환
  Future<String?> fetchPreviousYearPhoto({
    required String heritageId,
    String? location,
    String? partName,
    String? direction,
    String? number,
    String? position,
  }) async {
    try {
      // 현재 년도와 전년도 계산
      final now = DateTime.now();
      final currentYear = now.year;
      final lastYear = currentYear - 1;

      // 전년도 시작/종료 시간
      final lastYearStart = DateTime(lastYear, 1, 1);
      final lastYearEnd = DateTime(lastYear, 12, 31, 23, 59, 59);

      // 손상부 조사 컬렉션 쿼리
      var query = _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('damage_surveys')
          .where('timestamp', isGreaterThanOrEqualTo: lastYearStart.toIso8601String())
          .where('timestamp', isLessThanOrEqualTo: lastYearEnd.toIso8601String());

      // location 필드로 검색 (전체 위치 정보 포함)
      if (location != null && location.isNotEmpty) {
        query = query.where('location', isEqualTo: location);
      }

      final snapshot = await query
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('🔍 전년도 조사 사진 없음 (heritageId: $heritageId, location: $location)');
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      final imageUrl = data['imageUrl'] as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        debugPrint('✅ 전년도 조사 사진 로드 성공: $imageUrl');
        return imageUrl;
      }

      return null;
    } catch (e) {
      debugPrint('❌ 전년도 사진 로드 실패: $e');
      return null;
    }
  }
}
