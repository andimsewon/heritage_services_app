// lib/services/firebase_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:my_cross_app/models/section_form_models.dart';
import 'package:my_cross_app/core/utils/error_handler.dart';
import 'package:my_cross_app/core/utils/input_validator.dart';

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

  FirebaseService() {
    // Firestore 설정은 Flutter에서 자동으로 처리됨
    debugPrint('🔥 FirebaseService 초기화 완료');
  }

  /// 문화유산 사진 업로드 (현황/조사 공용)
  /// folder: 'photos' | 'damage_surveys'
  Future<String> uploadImage({
    required String heritageId,
    required String folder,
    required Uint8List bytes,
  }) async {
    // 입력 검증 (InputValidator 사용)
    final heritageIdError = InputValidator.validateHeritageId(heritageId);
    if (heritageIdError != null) {
      throw ArgumentError(heritageIdError);
    }
    final folderError = InputValidator.validateFolder(folder);
    if (folderError != null) {
      throw ArgumentError(folderError);
    }
    final imageSizeError = InputValidator.validateImageSize(bytes, maxSizeMB: 10);
    if (imageSizeError != null) {
      throw ArgumentError(imageSizeError);
    }

    try {
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
          'size': bytes.length.toString(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('이미지 업로드 시간이 초과되었습니다.');
        },
      );

      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        debugPrint('✅ 이미지 업로드 성공: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('Upload failed with state: ${uploadTask.state}');
      }
    } on TimeoutException {
      debugPrint('⏰ 이미지 업로드 타임아웃');
      rethrow;
    } catch (e, stackTrace) {
      // ErrorHandler를 사용한 에러 로깅
      ErrorHandler.logFirebaseError(e, 'uploadImage', stackTrace: stackTrace);

      // HTTP 환경에서의 Service Worker 오류인 경우 특별 처리
      if (kIsWeb &&
          (e.toString().contains('Service Worker') ||
              e.toString().contains('Secure Context') ||
              e.toString().contains('not secure'))) {
        throw SecureContextException(
            '이미지 업로드 실패: HTTPS 환경에서만 사용 가능합니다.\n'
            'Firebase Hosting에 배포하거나 HTTPS 환경에서 실행해주세요.');
      }

      // 사용자 친화적 에러 메시지
      final userMessage = ErrorHandler.getUserFriendlyMessage(e);
      throw Exception(userMessage);
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

  /// 현황 사진 스트림 (최적화)
  Stream<QuerySnapshot<Map<String, dynamic>>> photosStream(String heritageId, {String folder = 'photos'}) {
    return _fs
        .collection('heritages')
        .doc(heritageId)
        .collection(folder)
        .orderBy('timestamp', descending: true)
        .limit(20) // 최대 20개로 제한하여 성능 향상
        .snapshots();
  }

  /// 손상부 조사 스트림 (최신 먼저) - 최적화
  Stream<QuerySnapshot<Map<String, dynamic>>> damageStream(String heritageId) {
    return _fs
        .collection('heritages')
        .doc(heritageId)
        .collection('damage_surveys')
        .orderBy('timestamp', descending: true)
        .limit(10) // 최대 10개로 제한하여 성능 향상
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

  /// 상세 조사 데이터 저장 (문화유산별 구조)
  Future<void> addDetailSurvey({
    required String heritageId,
    required String heritageName,
    required Map<String, dynamic> surveyData,
  }) async {
    print('🚨 FirebaseService.addDetailSurvey 호출됨!');
    debugPrint('🚨 FirebaseService.addDetailSurvey 호출됨!');
    
    try {
      // Firebase 연결 상태 확인
      await _fs.enableNetwork();
      print('✅ Firestore 네트워크 연결 확인됨');
      
      print('🔥 Firebase 저장 시작...');
      debugPrint('🔥 Firebase 저장 시작...');
      print('  - HeritageId: $heritageId');
      print('  - HeritageName: $heritageName');
      debugPrint('  - HeritageId: $heritageId');
      debugPrint('  - HeritageName: $heritageName');
      debugPrint('  - Firestore 앱: ${_fs.app.name}');
      debugPrint('  - 프로젝트 ID: ${_fs.app.options.projectId}');
      
      // 문화유산별 컬렉션 구조 사용 (사진과 동일한 방식)
      final col = _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('detail_surveys');
      final id = const Uuid().v4();
      
      debugPrint('  - 컬렉션 경로: heritages/$heritageId/detail_surveys');
      debugPrint('  - 문서 ID: $id');
      
      // 저장할 데이터 준비 (사진과 동일한 구조)
      final dataToSave = {
        'heritageId': heritageId,
        'heritageName': heritageName,
        ...surveyData,
        'timestamp': DateTime.now().toIso8601String(),
        'version': 1, // 버전 추가
      };

      debugPrint('  - 저장할 데이터 키들: ${dataToSave.keys.toList()}');
      debugPrint('  - 데이터 크기: ${dataToSave.toString().length} 문자');
      
      // 1단계: set() 메서드로 저장 (사진과 동일한 방식)
      debugPrint('  - 1단계: set() 메서드로 저장 시도...');
      await col.doc(id).set(dataToSave);
      final docId = id;
      
      debugPrint('✅ Firebase 저장 완료!');
      debugPrint('  - 저장된 문서 ID: $docId');
      debugPrint('  - 저장된 시간: ${DateTime.now().toIso8601String()}');
      debugPrint('  - 컬렉션 경로: heritages/$heritageId/detail_surveys/$docId');
      
      // 2단계: 저장 후 즉시 확인
      debugPrint('  - 2단계: 저장 확인 중...');
      final savedDoc = await col.doc(docId).get();
      if (savedDoc.exists) {
        debugPrint('✅ 저장 확인 성공 - 문서가 실제로 존재합니다!');
        debugPrint('  - 문서 데이터 키들: ${savedDoc.data()?.keys.toList()}');
        
        // 3단계: 쿼리로 재확인 (사진과 동일한 방식)
        debugPrint('  - 3단계: 쿼리로 재확인 중...');
        final querySnapshot = await col
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
            
        if (querySnapshot.docs.isNotEmpty) {
          debugPrint('✅ 쿼리 확인 성공 - 쿼리로도 문서를 찾을 수 있습니다!');
          debugPrint('  - 쿼리 결과 문서 수: ${querySnapshot.docs.length}');
        } else {
          debugPrint('⚠️ 쿼리 확인 실패 - 쿼리로 문서를 찾을 수 없습니다.');
        }
        
      } else {
        debugPrint('❌ 저장 확인 실패 - 문서가 존재하지 않습니다!');
        throw Exception('문서 저장 후 확인 실패');
      }
      
    } catch (e) {
      debugPrint('❌ Firebase 저장 실패: $e');
      debugPrint('  - 오류 타입: ${e.runtimeType}');
      debugPrint('  - 오류 메시지: ${e.toString()}');
      
      // 구체적인 오류 분석
      if (e.toString().contains('permission-denied')) {
        debugPrint('🚨 권한 오류: Firestore 보안 규칙을 확인하세요!');
        debugPrint('   Firebase Console → Firestore Database → 규칙');
        debugPrint('   현재 규칙: allow read, write: if true;');
      } else if (e.toString().contains('network') || e.toString().contains('transport')) {
        debugPrint('🌐 네트워크 오류: 인터넷 연결을 확인하세요!');
        debugPrint('   WebChannelConnection 오류 - 네트워크 연결 문제');
        // 네트워크 재연결 시도
        try {
          await _fs.enableNetwork();
          debugPrint('🔄 네트워크 재연결 시도 중...');
        } catch (retryError) {
          debugPrint('❌ 네트워크 재연결 실패: $retryError');
        }
      } else if (e.toString().contains('quota')) {
        debugPrint('📊 할당량 초과: Firebase 할당량을 확인하세요!');
      } else if (e.toString().contains('unavailable')) {
        debugPrint('🔧 서비스 불가: Firebase 서비스 상태를 확인하세요!');
      } else if (e.toString().contains('timeout')) {
        debugPrint('⏰ 타임아웃: 요청 시간이 초과되었습니다!');
      }
      
      rethrow;
    }
  }

  /// 상세 조사 데이터 조회 (문화유산별 구조) - 최적화
  Future<QuerySnapshot<Map<String, dynamic>>> getDetailSurveys(String heritageId) async {
    try {
      // 캐시 우선 조회로 성능 향상
      return await _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('detail_surveys')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.cache));
    } catch (e) {
      // 캐시 실패시 서버에서 조회
      return await _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('detail_surveys')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
    }
  }

  /// 섹션 폼 데이터 저장
  Future<void> saveSectionForm({
    required String heritageId,
    required String sectionType,
    required dynamic formData,
  }) async {
    try {
      print('🚨 섹션 폼 저장 시작!');
      debugPrint('🚨 섹션 폼 저장 시작!');
      
      // Firebase 연결 상태 확인
      await _fs.enableNetwork();
      print('✅ Firestore 네트워크 연결 확인됨');
      
      final col = _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('section_forms')
          .doc(sectionType);
      
      debugPrint('  - 컬렉션 경로: heritages/$heritageId/section_forms/$sectionType');
      debugPrint('  - HeritageId: $heritageId');
      debugPrint('  - SectionType: $sectionType');
      
      // formData를 Map으로 변환
      Map<String, dynamic> formDataMap;
      if (formData is SectionFormData) {
        formDataMap = formData.toMap();
        debugPrint('  - SectionFormData 변환 완료');
      } else {
        debugPrint('  - formData 타입: ${formData.runtimeType}');
        formDataMap = formData.toMap();
      }
      
      final dataToSave = <String, dynamic>{
        'heritageId': heritageId,
        'sectionType': sectionType,
        ...formDataMap,
        'timestamp': DateTime.now().toIso8601String(),
        'version': 1,
      };
      
      debugPrint('  - 저장할 데이터 키들: ${dataToSave.keys.toList()}');
      debugPrint('  - 제목: ${dataToSave['title']}');
      debugPrint('  - 내용 길이: ${dataToSave['content']?.toString().length ?? 0}');
      
      // 데이터 저장
      final docRef = await col.collection('items').add(dataToSave);
      final docId = docRef.id;
      
      debugPrint('✅ 섹션 폼 저장 완료!');
      debugPrint('  - 저장된 문서 ID: $docId');
      
      // 저장 확인
      final savedDoc = await col.collection('items').doc(docId).get();
      if (savedDoc.exists) {
        debugPrint('✅ 저장 확인 성공 - 문서가 실제로 존재합니다!');
        debugPrint('  - 문서 데이터 키들: ${savedDoc.data()?.keys.toList()}');
      } else {
        debugPrint('❌ 저장 확인 실패 - 문서가 존재하지 않습니다!');
        throw Exception('문서 저장 후 확인 실패');
      }
      
    } catch (e) {
      debugPrint('❌ 섹션 폼 저장 실패: $e');
      debugPrint('  - 오류 타입: ${e.runtimeType}');
      debugPrint('  - 오류 메시지: ${e.toString()}');
      
      // 구체적인 오류 분석
      if (e.toString().contains('permission-denied')) {
        debugPrint('🚨 권한 오류: Firestore 보안 규칙을 확인하세요!');
      } else if (e.toString().contains('network') || e.toString().contains('transport')) {
        debugPrint('🌐 네트워크 오류: 인터넷 연결을 확인하세요!');
      } else if (e.toString().contains('quota')) {
        debugPrint('📊 할당량 초과: Firebase 할당량을 확인하세요!');
      } else if (e.toString().contains('unavailable')) {
        debugPrint('🔧 서비스 불가: Firebase 서비스 상태를 확인하세요!');
      }
      
      rethrow;
    }
  }

  /// 섹션 폼 데이터 스트림 조회
  Stream<QuerySnapshot<Map<String, dynamic>>> getSectionFormsStream(
    String heritageId,
    String sectionType,
  ) {
    return _fs
        .collection('heritages')
        .doc(heritageId)
        .collection('section_forms')
        .doc(sectionType)
        .collection('items')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// 섹션 폼 데이터 삭제
  Future<void> deleteSectionForm(
    String heritageId,
    String sectionType,
    String docId,
  ) async {
    try {
      await _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('section_forms')
          .doc(sectionType)
          .collection('items')
          .doc(docId)
          .delete();
      
      debugPrint('✅ 섹션 폼 삭제 완료!');
    } catch (e) {
      debugPrint('❌ 섹션 폼 삭제 실패: $e');
      rethrow;
    }
  }

  /// Firebase 연결 테스트
  Future<bool> testFirebaseConnection() async {
    try {
      debugPrint('🧪 Firebase 연결 테스트 시작...');
      debugPrint('  - Firestore 인스턴스: ${_fs.app.name}');
      debugPrint('  - 프로젝트 ID: ${_fs.app.options.projectId}');
      
      // 1. Firestore 연결 테스트
      final testCol = _fs.collection('_test_connection');
      final testDoc = testCol.doc('test_${DateTime.now().millisecondsSinceEpoch}');
      
      debugPrint('  - 테스트 컬렉션: _test_connection');
      debugPrint('  - 테스트 문서 ID: ${testDoc.id}');
      
      final testData = {
        'test': true,
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Firebase 연결 테스트 성공!',
        'heritageId': 'test_heritage',
        'heritageName': '테스트 문화유산',
      };
      
      debugPrint('  - 저장할 테스트 데이터: $testData');
      
      await testDoc.set(testData);
      debugPrint('✅ Firestore 쓰기 테스트 성공');
      
      // 2. 읽기 테스트
      final snapshot = await testDoc.get();
      if (snapshot.exists) {
        debugPrint('✅ Firestore 읽기 테스트 성공');
        debugPrint('  - 테스트 데이터: ${snapshot.data()}');
        
        // 3. 실제 detail_surveys 컬렉션 테스트 (문화유산별 구조)
        debugPrint('  - detail_surveys 컬렉션 테스트 시작...');
        final detailCol = _fs
            .collection('heritages')
            .doc('test_heritage')
            .collection('detail_surveys');
        final detailDoc = detailCol.doc('test_detail_${DateTime.now().millisecondsSinceEpoch}');
        
        final detailData = {
          'heritageId': 'test_heritage',
          'heritageName': '테스트 문화유산',
          'inspectionResult': '테스트 점검 결과',
          'section11': {
            'foundation': '테스트 기단부',
            'wall': '테스트 축부',
            'roof': '테스트 지붕부',
          },
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        await detailDoc.set(detailData);
        debugPrint('✅ detail_surveys 컬렉션 쓰기 테스트 성공');
        
        final detailSnapshot = await detailDoc.get();
        if (detailSnapshot.exists) {
          debugPrint('✅ detail_surveys 컬렉션 읽기 테스트 성공');
          debugPrint('  - 저장된 데이터: ${detailSnapshot.data()}');
        } else {
          debugPrint('❌ detail_surveys 컬렉션 읽기 테스트 실패');
          return false;
        }
        
        // 테스트 데이터 정리
        await detailDoc.delete();
        debugPrint('✅ detail_surveys 테스트 데이터 정리 완료');
        
      } else {
        debugPrint('❌ Firestore 읽기 테스트 실패 - 문서가 존재하지 않음');
        return false;
      }
      
      // 4. 테스트 데이터 삭제
      await testDoc.delete();
      debugPrint('✅ 테스트 데이터 정리 완료');
      
      debugPrint('🎉 Firebase 연결 테스트 완전 성공!');
      return true;
      
    } catch (e) {
      debugPrint('❌ Firebase 연결 테스트 실패: $e');
      debugPrint('  - 오류 타입: ${e.runtimeType}');
      debugPrint('  - 오류 메시지: ${e.toString()}');
      
      // 구체적인 오류 분석
      if (e.toString().contains('permission-denied')) {
        debugPrint('🚨 권한 오류: Firestore 보안 규칙을 확인하세요!');
      } else if (e.toString().contains('network')) {
        debugPrint('🌐 네트워크 오류: 인터넷 연결을 확인하세요!');
      } else if (e.toString().contains('quota')) {
        debugPrint('📊 할당량 초과: Firebase 할당량을 확인하세요!');
      }
      
      return false;
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

  /// 연도별 데이터 저장
  Future<void> saveYearData(String heritageId, String year, Map<String, dynamic> data) async {
    try {
      debugPrint('📅 연도별 데이터 저장 시작: $heritageId, $year');
      
      final docRef = _fs.collection('heritages').doc(heritageId).collection('yearly_data').doc(year);
      
      await docRef.set({
        ...data,
        'year': year,
        'heritageId': heritageId,
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ 연도별 데이터 저장 완료: $year');
    } catch (e) {
      debugPrint('❌ 연도별 데이터 저장 실패: $e');
      rethrow;
    }
  }

  /// 연도별 데이터 불러오기
  Future<Map<String, dynamic>?> getYearData(String heritageId, String year) async {
    try {
      debugPrint('📅 연도별 데이터 불러오기 시작: $heritageId, $year');
      
      final docRef = _fs.collection('heritages').doc(heritageId).collection('yearly_data').doc(year);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('✅ 연도별 데이터 불러오기 완료: $year');
        return data;
      } else {
        debugPrint('⚠️ 연도별 데이터 없음: $year');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 연도별 데이터 불러오기 실패: $e');
      rethrow;
    }
  }

  /// 연도별 데이터 목록 조회
  Future<List<String>> getYearList(String heritageId) async {
    try {
      debugPrint('📅 연도별 데이터 목록 조회 시작: $heritageId');
      
      final querySnapshot = await _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('yearly_data')
          .orderBy('year', descending: true)
          .get();
      
      final years = querySnapshot.docs.map((doc) => doc.id).toList();
      debugPrint('✅ 연도별 데이터 목록 조회 완료: $years');
      return years;
    } catch (e) {
      debugPrint('❌ 연도별 데이터 목록 조회 실패: $e');
      return [];
    }
  }

  /// 메타 정보 저장 (조사 일자, 조사 기관, 조사자)
  Future<void> saveMetaInfo({
    required String heritageId,
    required String heritageName,
    required String surveyDate,
    required String organization,
    required String investigator,
  }) async {
    try {
      debugPrint('📋 메타 정보 저장 시작: $heritageId');
      
      await _fs.collection('heritages').doc(heritageId).set({
        'metaInfo': {
          'surveyDate': surveyDate,
          'organization': organization,
          'investigator': investigator,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'heritageName': heritageName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ 메타 정보 저장 완료');
    } catch (e) {
      debugPrint('❌ 메타 정보 저장 실패: $e');
      rethrow;
    }
  }

  /// 메타 정보 불러오기
  Future<Map<String, dynamic>?> getMetaInfo(String heritageId) async {
    try {
      debugPrint('📋 메타 정보 불러오기 시작: $heritageId');
      
      final doc = await _fs.collection('heritages').doc(heritageId).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final metaInfo = data['metaInfo'] as Map<String, dynamic>?;
        debugPrint('✅ 메타 정보 불러오기 완료');
        return metaInfo;
      } else {
        debugPrint('⚠️ 메타 정보 없음');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 메타 정보 불러오기 실패: $e');
      rethrow;
    }
  }

  /// 손상부 조사 데이터 저장
  Future<String> saveDamageSurvey({
    required String heritageId,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint('🔍 손상부 조사 데이터 저장 시작: $heritageId');
      
      final docRef = _fs.collection('heritages').doc(heritageId).collection('damage_surveys').doc();
      
      await docRef.set({
        ...data,
        'heritageId': heritageId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ 손상부 조사 데이터 저장 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ 손상부 조사 데이터 저장 실패: $e');
      rethrow;
    }
  }

  /// 손상부 조사 데이터 업데이트
  Future<void> updateDamageSurvey({
    required String heritageId,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint('🔍 손상부 조사 데이터 업데이트 시작: $heritageId/$docId');
      
      final docRef = _fs.collection('heritages').doc(heritageId).collection('damage_surveys').doc(docId);
      
      await docRef.update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ 손상부 조사 데이터 업데이트 완료: $docId');
    } catch (e) {
      debugPrint('❌ 손상부 조사 데이터 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 조사자 의견 섹션 수정 이력 저장
  Future<void> saveEditHistory({
    required String heritageId,
    required String sectionType, // 'inspectionResult', 'preservationItems', 'management'
    required String editor,
    required List<String> changedFields,
  }) async {
    try {
      debugPrint('📝 수정 이력 저장 시작: $heritageId/$sectionType');
      
      final col = _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('edit_history');
      
      await col.add({
        'sectionType': sectionType,
        'editor': editor,
        'changedFields': changedFields,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      debugPrint('✅ 수정 이력 저장 완료');
    } catch (e) {
      debugPrint('❌ 수정 이력 저장 실패: $e');
      rethrow;
    }
  }

  /// 조사자 의견 섹션 수정 이력 조회
  Stream<QuerySnapshot<Map<String, dynamic>>> editHistoryStream(String heritageId) {
    return _fs
        .collection('heritages')
        .doc(heritageId)
        .collection('edit_history')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  /// 조사자 의견 섹션 데이터 저장 (수정 이력 포함)
  Future<void> saveInvestigatorOpinionSection({
    required String heritageId,
    required String sectionType,
    required Map<String, dynamic> data,
    String? editor,
    List<String>? changedFields,
  }) async {
    try {
      debugPrint('💾 조사자 의견 섹션 저장 시작: $heritageId/$sectionType');
      
      final docRef = _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('investigator_opinion')
          .doc(sectionType);
      
      await docRef.set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastEditor': editor ?? '현재 사용자',
      }, SetOptions(merge: true));
      
      // 수정 이력 저장
      if (editor != null && changedFields != null && changedFields.isNotEmpty) {
        await saveEditHistory(
          heritageId: heritageId,
          sectionType: sectionType,
          editor: editor,
          changedFields: changedFields,
        );
      }
      
      debugPrint('✅ 조사자 의견 섹션 저장 완료');
    } catch (e) {
      debugPrint('❌ 조사자 의견 섹션 저장 실패: $e');
      rethrow;
    }
  }

  /// 손상 평가 요약 저장
  Future<void> saveDamageAssessmentSummary({
    required String heritageId,
    required Map<String, dynamic> damageSummary,
  }) async {
    try {
      debugPrint('💾 손상 평가 요약 저장 시작: $heritageId');
      
      final docRef = _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('detail_surveys')
          .doc('damage_assessment_summary');
      
      await docRef.set({
        ...damageSummary,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ 손상 평가 요약 저장 완료');
    } catch (e) {
      debugPrint('❌ 손상 평가 요약 저장 실패: $e');
      rethrow;
    }
  }

  /// 손상 평가 요약 조회
  Future<Map<String, dynamic>?> getDamageAssessmentSummary({
    required String heritageId,
  }) async {
    try {
      debugPrint('📖 손상 평가 요약 조회 시작: $heritageId');
      
      final doc = await _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('detail_surveys')
          .doc('damage_assessment_summary')
          .get();
      
      if (!doc.exists) {
        debugPrint('⚠️ 손상 평가 요약 데이터 없음');
        return null;
      }
      
      final data = doc.data();
      debugPrint('✅ 손상 평가 요약 조회 완료');
      return data;
    } catch (e) {
      debugPrint('❌ 손상 평가 요약 조회 실패: $e');
      rethrow;
    }
  }

  /// 손상 평가 요약 스트림 (실시간 업데이트)
  Stream<DocumentSnapshot<Map<String, dynamic>>> damageAssessmentSummaryStream(
    String heritageId,
  ) {
    return _fs
        .collection('heritages')
        .doc(heritageId)
        .collection('detail_surveys')
        .doc('damage_assessment_summary')
        .snapshots();
  }

  /// 조사자 의견 섹션 데이터 조회
  Future<Map<String, dynamic>?> getInvestigatorOpinionSection({
    required String heritageId,
    required String sectionType,
  }) async {
    try {
      final doc = await _fs
          .collection('heritages')
          .doc(heritageId)
          .collection('investigator_opinion')
          .doc(sectionType)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ 조사자 의견 섹션 조회 실패: $e');
      return null;
    }
  }

}
