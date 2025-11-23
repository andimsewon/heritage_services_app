import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:my_cross_app/models/damage_summary_models.dart';

/// 손상부 종합 서비스
///
/// 손상부 조사 데이터를 로드하고 O/X/O 형식으로 변환하여
/// 손상부 종합 테이블에 표시할 수 있도록 처리합니다.
class DamageSummaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 손상부 조사 기록 로드
  ///
  /// Firestore의 damage_surveys 컬렉션에서 모든 기록을 가져옵니다.
  Future<List<DamageRecord>> loadInspectionRecords(String heritageId) async {
    try {
      final snapshot = await _firestore
          .collection('heritages')
          .doc(heritageId)
          .collection('damage_surveys')
          .get();

      final records = <DamageRecord>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          // location 필드에서 부재 정보 추출
          final location = data['location'] as String? ?? '';
          final partName = data['partName'] as String?;
          final partNumber = data['partNumber'] as String?;
          final direction = data['direction'] as String?;
          final position = data['position'] as String?;
          final phenomenon = data['phenomenon'] as String? ?? '';

          // phenomenon에서 손상 유형 추출
          final subType = _extractSubType(phenomenon, location);
          if (subType.isEmpty) continue;

          // category 결정
          final category = _determineCategory(subType, phenomenon);

          // componentId 생성 (부재명 + 부재번호 + 향)
          final componentId = _buildComponentId(
            partName,
            partNumber,
            direction,
          );

          records.add(
            DamageRecord(
              id: doc.id,
              heritageId: heritageId,
              componentId: componentId,
              partName: partName,
              partNumber: partNumber,
              direction: direction,
              position: _normalizePosition(position),
              category: category,
              subType: subType,
              timestamp: data['timestamp'] != null
                  ? DateTime.tryParse(data['timestamp'].toString())
                  : null,
            ),
          );
        } catch (e) {
          debugPrint('⚠️ 손상부 조사 기록 파싱 실패 (${doc.id}): $e');
        }
      }

      return records;
    } catch (e) {
      debugPrint('❌ 손상부 조사 기록 로드 실패: $e');
      return [];
    }
  }

  /// 손상 유형 추출
  String _extractSubType(String phenomenon, String location) {
    if (phenomenon.isEmpty) return '';

    // 구조적 손상
    if (phenomenon.contains('이격') || phenomenon.contains('이완')) return '이격/이완';
    if (phenomenon.contains('기울')) return '기울';
    if (phenomenon.contains('들림')) return '들림';
    if (phenomenon.contains('축 변형')) return '축 변형';
    if (phenomenon.contains('침하')) return '침하';
    if (phenomenon.contains('처짐') || phenomenon.contains('휨')) return '처짐/휨';
    if (phenomenon.contains('비틀림')) return '비틀림';
    if (phenomenon.contains('돌아감')) return '돌아감';
    if (phenomenon.contains('유실')) return '유실';
    if (phenomenon.contains('분리')) return '분리';
    if (phenomenon.contains('부러짐')) return '부러짐';

    // 물리적 손상
    if (phenomenon.contains('균열')) return '균열';
    if (phenomenon.contains('갈래')) return '갈래';
    if (phenomenon.contains('탈락')) return '탈락';
    if (phenomenon.contains('들뜸')) return '들뜸';
    if (phenomenon.contains('박리') || phenomenon.contains('박락')) return '박리/박락';

    // 생물·화학적 손상
    if (phenomenon.contains('부후')) return '부후';
    if (phenomenon.contains('식물') || phenomenon.contains('생장')) return '식물생장';
    if (phenomenon.contains('오염') || phenomenon.contains('균')) return '표면 오염균';
    if (phenomenon.contains('공동')) return '공동화';
    if (phenomenon.contains('천공')) return '천공';
    if (phenomenon.contains('변색')) return '변색';

    return phenomenon; // 원본 반환
  }

  /// 카테고리 결정
  DamageCategory _determineCategory(String subType, String phenomenon) {
    // 구조적 손상
    if ([
      '이격/이완',
      '기울',
      '들림',
      '축 변형',
      '침하',
      '처짐/휨',
      '비틀림',
      '돌아감',
      '유실',
      '분리',
      '부러짐',
    ].contains(subType)) {
      return DamageCategory.structural;
    }
    // 물리적 손상
    if (['균열', '갈래', '탈락', '들뜸', '박리/박락'].contains(subType)) {
      return DamageCategory.physical;
    }
    // 생물·화학적 손상
    if (['부후', '식물생장', '표면 오염균', '공동화', '천공', '변색'].contains(subType)) {
      return DamageCategory.biochemical;
    }

    // phenomenon으로 재확인
    final lower = phenomenon.toLowerCase();
    if (lower.contains('구조') || lower.contains('변형') || lower.contains('파손')) {
      return DamageCategory.structural;
    }
    if (lower.contains('물리') || lower.contains('균열') || lower.contains('박리')) {
      return DamageCategory.physical;
    }
    if (lower.contains('생물') || lower.contains('화학') || lower.contains('부후')) {
      return DamageCategory.biochemical;
    }

    return DamageCategory.structural; // 기본값
  }

  /// 구성요소 ID 생성
  String _buildComponentId(
    String? partName,
    String? partNumber,
    String? direction,
  ) {
    final parts = <String>[];
    if (partName != null && partName.isNotEmpty) parts.add(partName);
    if (partNumber != null && partNumber.isNotEmpty) parts.add('$partNumber번');
    if (direction != null && direction.isNotEmpty) parts.add('($direction)');
    return parts.join(' ');
  }

  /// 위치 정규화 (좌측/중앙/우측)
  String? _normalizePosition(String? position) {
    if (position == null || position.isEmpty) return null;
    switch (position) {
      case '상':
      case '좌':
      case '좌측':
        return '좌측';
      case '중':
      case '중앙':
        return '중앙';
      case '하':
      case '우':
      case '우측':
        return '우측';
      default:
        return position;
    }
  }

  /// O/X/O 문자열 생성
  ///
  /// 좌/중앙/우측 위치 목록을 받아 손상 여부를 변환합니다.
  ///
  /// 예시:
  /// - 위치: [좌측, 우측] → "O/X/O"
  /// - 위치: [중앙] → "X/O/X"
  String buildOXString(List<String> positions) {
    bool hasLeft = false;
    bool hasCenter = false;
    bool hasRight = false;

    for (final position in positions) {
      switch (position) {
        case '좌측':
          hasLeft = true;
          break;
        case '중앙':
          hasCenter = true;
          break;
        case '우측':
          hasRight = true;
          break;
      }
    }

    return '${hasLeft ? "O" : "X"}/${hasCenter ? "O" : "X"}/${hasRight ? "O" : "X"}';
  }

  /// 손상 기록 리스트를 받아 손상 유형별 O/X/O 요약 생성
  Map<String, String> summarizeDamage(List<DamageRecord> records) {
    final grouped = <String, List<String>>{};

    for (final record in records) {
      final subType = record.subType.trim();
      if (subType.isEmpty) continue;
      final position = record.position;
      if (position == null || position.isEmpty) continue;
      grouped.putIfAbsent(subType, () => <String>[]).add(position);
    }

    final result = <String, String>{};
    for (final entry in grouped.entries) {
      result[entry.key] = buildOXString(entry.value);
    }
    return result;
  }

  /// 카테고리별 손상 요약
  ///
  /// 특정 카테고리의 모든 손상 유형에 대해 O/X/O 문자열을 생성합니다.
  Map<String, String> summarizeCategory(
    List<DamageRecord> allRecords,
    DamageCategory category,
  ) {
    final categoryRecords = allRecords
        .where((r) => r.category == category)
        .toList();
    if (categoryRecords.isEmpty) {
      return {};
    }
    return summarizeDamage(categoryRecords);
  }

  /// 전체 손상 요약 생성
  ///
  /// 구성요소별로 손상부 종합을 생성합니다.
  Future<List<DamageSummaryData>> summarizeDamageByHeritage(
    String heritageId,
  ) async {
    final records = await loadInspectionRecords(heritageId);

    // 구성요소별로 그룹화
    final byComponent = <String, List<DamageRecord>>{};
    for (final record in records) {
      final key = record.componentId ?? 'unknown';
      byComponent.putIfAbsent(key, () => []).add(record);
    }

    final summaries = <DamageSummaryData>[];
    for (final entry in byComponent.entries) {
      final componentRecords = entry.value;
      final componentId = entry.key;
      final componentName = componentRecords.first.componentId ?? componentId;

      summaries.add(
        DamageSummaryData(
          heritageId: heritageId,
          componentId: componentId,
          componentName: componentName,
          structural: summarizeCategory(
            componentRecords,
            DamageCategory.structural,
          ),
          physical: summarizeCategory(
            componentRecords,
            DamageCategory.physical,
          ),
          biochemical: summarizeCategory(
            componentRecords,
            DamageCategory.biochemical,
          ),
          timestamp: DateTime.now(),
        ),
      );
    }

    return summaries;
  }

  /// 손상부 종합 Firestore 저장
  Future<void> saveComponentSummaryToFirestore(
    DamageSummaryData summary,
  ) async {
    try {
      await _firestore
          .collection('heritages')
          .doc(summary.heritageId)
          .collection('damage_summaries')
          .doc(summary.componentId)
          .set(summary.toMap(), SetOptions(merge: true));

      debugPrint('✅ 손상부 종합 저장 완료: ${summary.componentId}');
    } catch (e) {
      debugPrint('❌ 손상부 종합 저장 실패: $e');
      rethrow;
    }
  }

  /// 손상부 종합 Firestore 로드
  Future<DamageSummaryData?> loadComponentSummaryFromFirestore(
    String heritageId,
    String componentId,
  ) async {
    try {
      final doc = await _firestore
          .collection('heritages')
          .doc(heritageId)
          .collection('damage_summaries')
          .doc(componentId)
          .get();

      if (!doc.exists) return null;

      return DamageSummaryData.fromFirestore(doc.data()!);
    } catch (e) {
      debugPrint('❌ 손상부 종합 로드 실패: $e');
      return null;
    }
  }

  /// 손상부 종합 요약 Firestore 저장
  Future<void> saveSummaryToFirestore({
    required String heritageId,
    required Map<String, Map<String, String>> summary,
    required Map<String, String> grade,
  }) async {
    try {
      final docRef = _firestore
          .collection('heritages')
          .doc(heritageId)
          .collection('detail_surveys')
          .doc('damage_assessment_summary');

      final payload = {
        'structural': summary['structural'] ?? {},
        'physical': summary['physical'] ?? {},
        'biochemical': summary['biochemical'] ?? {},
        'grade': grade,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set({'damage_summary': payload}, SetOptions(merge: true));

      debugPrint('✅ 손상부 종합 저장 완료 (damage_summary)');
    } catch (e) {
      debugPrint('❌ 손상부 종합 저장 실패: $e');
      rethrow;
    }
  }

  /// 손상부 종합 요약 Firestore 로드
  Future<Map<String, dynamic>?> loadSummaryFromFirestore(
    String heritageId,
  ) async {
    try {
      final doc = await _firestore
          .collection('heritages')
          .doc(heritageId)
          .collection('detail_surveys')
          .doc('damage_assessment_summary')
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) return null;
      final summary = data['damage_summary'];
      if (summary is Map<String, dynamic>) {
        return summary;
      }
      return null;
    } catch (e) {
      debugPrint('❌ 손상부 종합 요약 로드 실패: $e');
      return null;
    }
  }

  /// 손상부 종합 스트림 (실시간 업데이트)
  Stream<DocumentSnapshot<Map<String, dynamic>>> summaryStream(
    String heritageId,
    String componentId,
  ) {
    return _firestore
        .collection('heritages')
        .doc(heritageId)
        .collection('damage_summaries')
        .doc(componentId)
        .snapshots();
  }
}
