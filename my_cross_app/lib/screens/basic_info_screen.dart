import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert' show base64Decode; // base64Decode 사용 대비
import 'dart:async'; // Timer(debounce) 대비

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../data/heritage_api.dart';
import '../env.dart';
import '../services/firebase_service.dart';
import '../services/ai_detection_service.dart';
import '../services/image_acquire.dart';
import 'improved_damage_survey_dialog.dart';

// ── 누락된 설정용 타입 (const로 쓰기 때문에 반드시 const 생성자 필요)
/// ④ 기본개요 화면
class BasicInfoScreen extends StatefulWidget {
  static const route = '/basic-info';
  const BasicInfoScreen({super.key});

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  Map<String, dynamic>? _args;
  Map<String, dynamic>? _detail; // 상세 API 원본(JSON)
  bool _loading = true;
  late String heritageId;
  late final HeritageApi _api = HeritageApi(Env.proxyBase);
  final _fb = FirebaseService();
  final _ai = AiDetectionService(
    baseUrl: Env.proxyBase.replaceFirst(':8080', ':8081'),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args == null) {
      _args =
          (ModalRoute.of(context)?.settings.arguments ?? {})
              as Map<String, dynamic>;
      final isCustom = _args?['isCustom'] == true;
      if (isCustom) {
        // 커스텀은 고유 키 조합이 없으므로 customId 사용
        heritageId = 'CUSTOM_${_args?['customId'] ?? 'UNKNOWN'}';
      } else {
        heritageId =
            "${_args?['ccbaKdcd']}_${_args?['ccbaAsno']}_${_args?['ccbaCtcd']}";
      }
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_args?['isCustom'] == true) {
        // Firestore에 저장된 커스텀 유산 문서를 불러와 기본개요를 구성
        final customId = _args?['customId'] as String?;
        if (customId != null && customId.isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('custom_heritages')
              .doc(customId)
              .get();
          final m = snap.data() ?? <String, dynamic>{};
          setState(
            () => _detail = {
              'item': {
                'ccbaMnm1': (m['name'] as String?) ?? (_args?['name'] ?? ''),
                'ccmaName': m['ccmaName'] ?? m['kindName'],
                'ccbaAsdt': m['ccbaAsdt'] ?? m['asdt'],
                'ccbaPoss': m['ccbaPoss'] ?? m['owner'],
                'ccbaAdmin': m['ccbaAdmin'] ?? m['admin'],
                'ccbaLcto': m['ccbaLcto'] ?? m['lcto'],
                'ccbaLcad': m['ccbaLcad'] ?? m['lcad'],
              },
            },
          );
        } else {
          // 폴백: 전달된 인자만으로 구성
          setState(
            () => _detail = {
              'item': {'ccbaMnm1': _args?['name'] ?? ''},
            },
          );
        }
      } else {
        final d = await _api.fetchDetail(
          ccbaKdcd: _args?['ccbaKdcd'] ?? '',
          ccbaAsno: _args?['ccbaAsno'] ?? '',
          ccbaCtcd: _args?['ccbaCtcd'] ?? '',
        );
        setState(() => _detail = d);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상세 로드 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _read(List<List<String>> paths) {
    if (_detail == null) return '';
    for (final path in paths) {
      dynamic cur = _detail;
      var ok = true;
      for (final k in path) {
        if (cur is Map<String, dynamic> && cur.containsKey(k)) {
          cur = cur[k];
        } else {
          ok = false;
          break;
        }
      }
      if (ok && cur != null) return cur.toString();
    }
    return '';
  }

  String get _name => _read([
    ['result', 'item', 'ccbaMnm1'],
    ['item', 'ccbaMnm1'],
  ]);

  String _formatBytes(num? b) {
    final bytes = (b ?? 0).toDouble();
    if (bytes < 1024) return '${bytes.toInt()}B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)}MB';
  }

  // ───────────────────────── 문화유산 현황 사진 업로드
  Future<void> _addPhoto() async {
    if (!mounted) return;
    final pair = await ImageAcquire.pick(context);
    if (pair == null) return;
    final (bytes, sizeGetter) = pair;

    if (!mounted) return;
    final title = await _askTitle(context);
    if (title == null) return;

    await _fb.addPhoto(
      heritageId: heritageId,
      heritageName: _name,
      title: title,
      imageBytes: bytes,
      sizeGetter: sizeGetter,
    );
  }

  Future<String?> _askTitle(BuildContext context) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사진 제목 입력'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: '예: 남측면 전경'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 손상부 조사 촬영→AI 분석→저장
  Future<void> _startDamageSurvey() async {
    await _openDamageDetectionDialog(autoCapture: true);
  }

  Future<void> _openDamageDetectionDialog({bool autoCapture = false}) async {
    if (!mounted) return;
    final result = await showDialog<DamageDetectionResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImprovedDamageSurveyDialog(
        aiService: _ai,
        heritageId: heritageId,
        autoCapture: autoCapture,
      ),
    );

    if (result == null) return;

    final severity = (result.severityGrade?.trim().isNotEmpty ?? false)
        ? result.severityGrade
        : result.autoGrade;

    await _fb.addDamageSurvey(
      heritageId: heritageId,
      heritageName: _name,
      imageBytes: result.imageBytes,
      detections: result.detections,
      location: result.location,
      phenomenon: result.selectedLabel,
      inspectorOpinion: result.opinion,
      severityGrade: severity,
      detailInputs: result.toDetailInputs(),
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('손상부 조사 등록 완료')));
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('해당 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final kind = _read([
      ['result', 'item', 'ccmaName'],
      ['item', 'ccmaName'],
    ]);
    final asdt = _read([
      ['result', 'item', 'ccbaAsdt'],
      ['item', 'ccbaAsdt'],
    ]);
    final owner = _read([
      ['result', 'item', 'ccbaPoss'],
      ['item', 'ccbaPoss'],
    ]);
    final admin = _read([
      ['result', 'item', 'ccbaAdmin'],
      ['item', 'ccbaAdmin'],
    ]);
    final lcto = _read([
      ['result', 'item', 'ccbaLcto'],
      ['item', 'ccbaLcto'],
    ]);
    final lcad = _read([
      ['result', 'item', 'ccbaLcad'],
      ['item', 'ccbaLcad'],
    ]);

    // 반응형 설정
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 40.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF3B4C59),
        centerTitle: true,
        title: Text(
          _name.isEmpty ? '기본개요' : _name,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isMobile)
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HeritageHistoryDialog(
                      heritageId: heritageId,
                      heritageName: _name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 24),
              tooltip: '기존이력 확인',
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HeritageHistoryDialog(
                      heritageId: heritageId,
                      heritageName: _name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 22),
              label: const Text('기존이력 확인'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C8BF5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isMobile ? 16 : 24),
              children: [
                // ① 기본개요 섹션
                const Text(
                  '기본개요',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: isMobile ? screenWidth - (horizontalPadding * 2) : screenWidth,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.white,
                      ),
                      child: Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columnWidths: isMobile ? const {
                          0: IntrinsicColumnWidth(),
                          1: IntrinsicColumnWidth(),
                          2: IntrinsicColumnWidth(),
                          3: IntrinsicColumnWidth(),
                        } : const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(2.5),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(2.5),
                        },
                        children: [
                          TableRow(
                            children: [
                              _TableHeaderCell('국가유산명'),
                              _TableCell(_name.isEmpty ? '미상' : _name),
                              _TableHeaderCell('종목'),
                              _TableCell(kind),
                            ],
                          ),
                          TableRow(
                            children: [
                              _TableHeaderCell('지정(등록)일'),
                              _TableCell(asdt),
                              _TableHeaderCell('소유자'),
                              _TableCell(owner),
                            ],
                          ),
                          TableRow(
                            children: [
                              _TableHeaderCell('관리자'),
                              _TableCell(admin),
                              _TableHeaderCell('소재지'),
                              _TableCell(lcto),
                            ],
                          ),
                          if (lcad.isNotEmpty)
                            TableRow(
                              children: [
                                _TableHeaderCell('소재지 상세'),
                                _TableCell(lcad, colspan: 3),
                                const SizedBox.shrink(),
                                const SizedBox.shrink(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ② 보존관리 이력 섹션
                const Text(
                  '보존관리 이력',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 6),
                  child: Text(
                    '* 과거 최초 기록부터 현재까지 정비·보수·수리 내용',
                    style: TextStyle(fontSize: 13, color: Colors.redAccent),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xfff9f9f8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    '보존관리 이력 데이터가 없습니다.\n향후 업데이트 예정입니다.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 28),

                // ───── 문화유산 현황(사진)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '문화유산 현황',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    FilledButton.icon(
                      onPressed: _addPhoto,
                      icon: const Icon(Icons.add_a_photo, size: 18),
                      label: const Text('사진 등록'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4C8BF5),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _fb.photosStream(heritageId),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text('등록된 사진이 없습니다'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final d = docs[i].data();
                          return _PhotoCard(
                            title: (d['title'] as String?) ?? '',
                            url: (d['url'] as String?) ?? '',
                            meta:
                                '${d['width'] ?? '?'}x${d['height'] ?? '?'} • ${_formatBytes(d['bytes'] as num?)}',
                            onDelete: () async {
                              final ok = await _confirmDelete(context);
                              if (ok != true) return;
                              await _fb.deletePhoto(
                                heritageId: heritageId,
                                docId: docs[i].id,
                                url: (d['url'] as String?) ?? '',
                                folder: 'photos',
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // ───── 손상부 조사
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '손상부 조사',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _openDamageDetectionDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('조사 등록'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4C8BF5),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            final result = await showDialog(
                              context: context,
                              builder: (_) => const DeepDamageInspectionDialog(),
                            );
                            if (result != null && result['saved'] == true && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('심화조사 데이터가 저장되었습니다')),
                              );
                            }
                          },
                          icon: const Icon(Icons.assignment, size: 18),
                          label: const Text('심화조사'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4C8BF5),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 240,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _fb.damageStream(heritageId),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text('등록된 손상부 조사가 없습니다'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: docs
                            .where(
                              (e) =>
                                  ((e.data())['imageUrl'] as String?)?.isNotEmpty ==
                                  true,
                            )
                            .length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final filtered = docs
                              .where(
                                (e) =>
                                    ((e.data())['imageUrl'] as String?)?.isNotEmpty ==
                                    true,
                              )
                              .toList();
                          final doc = filtered[i];
                          final d = doc.data();
                          final url = d['imageUrl'] as String? ?? '';
                          final dets = (d['detections'] as List? ?? [])
                              .cast<Map<String, dynamic>>();
                          final grade = d['severityGrade'] as String?;
                          final loc = d['location'] as String?;
                          final phe = d['phenomenon'] as String?;
                          return _DamageCard(
                            url: url,
                            detections: dets,
                            severityGrade: grade,
                            location: loc,
                            phenomenon: phe,
                            onDelete: () async {
                              final ok = await _confirmDelete(context);
                              if (ok != true) return;
                              await _fb.deleteDamageSurvey(
                                heritageId: heritageId,
                                docId: doc.id,
                                imageUrl: url,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // ───── 주요 점검결과
                const Text(
                  '주요 점검결과',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _fb.damageStream(heritageId),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Center(
                          child: Text(
                            '손상부 조사 데이터 로딩 중...',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      );
                    }

                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '아직 등록된 손상부 조사가 없습니다.\n조사를 등록하면 자동으로 집계됩니다.',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // 손상 데이터 집계
                    final Map<String, int> gradeCount = {};
                    final Map<String, List<String>> partByGrade = {};
                    int totalCount = 0;

                    for (final doc in docs) {
                      final data = doc.data();
                      final grade = (data['severityGrade'] as String?)?.toUpperCase();
                      final location = data['location'] as String?;

                      if (grade != null && grade.isNotEmpty) {
                        gradeCount[grade] = (gradeCount[grade] ?? 0) + 1;
                        totalCount++;

                        if (location != null && location.isNotEmpty) {
                          partByGrade[grade] = partByGrade[grade] ?? [];
                          partByGrade[grade]!.add(location);
                        }
                      }
                    }

                    // 평균 등급 계산 (A=1, B=2, ... F=6)
                    final gradeValues = {'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6};
                    double avgValue = 0;
                    gradeCount.forEach((grade, count) {
                      avgValue += (gradeValues[grade] ?? 3) * count;
                    });
                    avgValue = totalCount > 0 ? avgValue / totalCount : 0;

                    String avgGrade = 'C';
                    if (avgValue <= 1.5) avgGrade = 'A';
                    else if (avgValue <= 2.5) avgGrade = 'B';
                    else if (avgValue <= 3.5) avgGrade = 'C';
                    else if (avgValue <= 4.5) avgGrade = 'D';
                    else if (avgValue <= 5.5) avgGrade = 'E';
                    else avgGrade = 'F';

                    // 등급별 색상
                    Color getGradeColor(String grade) {
                      switch (grade) {
                        case 'A': return Colors.green.shade600;
                        case 'B': return Colors.blue.shade600;
                        case 'C': return Colors.orange.shade600;
                        case 'D': return Colors.deepOrange.shade600;
                        case 'E': return Colors.red.shade600;
                        case 'F': return Colors.red.shade900;
                        default: return Colors.grey.shade600;
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E6EA)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 전체 요약
                          Row(
                            children: [
                              Icon(Icons.assessment, color: const Color(0xFF4C8BF5), size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '종합 상태',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6C757D),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '평균 등급: ',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: getGradeColor(avgGrade).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: getGradeColor(avgGrade),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            '$avgGrade 등급',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: getGradeColor(avgGrade),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(총 ${totalCount}건)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          // 등급별 상세
                          const Text(
                            '등급별 현황',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C757D),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: gradeCount.entries.map((entry) {
                              final grade = entry.key;
                              final count = entry.value;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: getGradeColor(grade).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: getGradeColor(grade).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$grade 등급',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: getGradeColor(grade),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: getGradeColor(grade),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$count건',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ───── 조사자 의견
                const Text(
                  '조사자 의견',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '조사자의 의견을 입력하세요',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ───── 조사자 종합의견
                const Text(
                  '조사자 종합의견',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: '조사자의 종합 의견을 입력하세요',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),

                const SizedBox(height: 120), // 하단 버튼 공간 확보
              ],
            ),
          ),

          // ───── 하단 고정 버튼
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      // TODO: 수정 모드 토글
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFF3B4C59)),
                      foregroundColor: const Color(0xFF3B4C59),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 30,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('수정'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: 저장 기능
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('변경사항이 저장되었습니다')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C8BF5),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 30,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, String? value) : value = value ?? '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String title, url, meta;
  final Future<void> Function()? onDelete;
  const _PhotoCard({
    required this.title,
    required this.url,
    required this.meta,
    this.onDelete,
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
      final proxyBase = Env.proxyBase;
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
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 4),
          Text(
            '이미지 로딩 실패',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            'URL 확인 필요',
            style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        elevation: 0.6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Expanded(
            child: _isValidUrl(url)
                  ? CachedNetworkImage(
                      imageUrl: _getProxiedUrl(url),
                      width: double.infinity,
                      fit: BoxFit.cover,
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
                    )
                  : _buildErrorWidget(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        meta,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: '삭제',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _DamagePreview extends StatelessWidget {
  final String url;
  final List<Map<String, dynamic>> detections; // label, score, x,y,w,h
  const _DamagePreview({required this.url, required this.detections});

  String _getProxiedUrl(String originalUrl) {
    // Firebase Storage URL인 경우 프록시 서버를 통해 로드
    if (originalUrl.contains('firebasestorage.googleapis.com')) {
      final proxyBase = Env.proxyBase;
      return '$proxyBase/image/proxy?url=${Uri.encodeComponent(originalUrl)}';
    }
    // 다른 URL은 그대로 사용
    return originalUrl;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: _getProxiedUrl(url),
              fit: BoxFit.contain,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  color: Colors.blue.shade400,
                  strokeWidth: 2,
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Icon(Icons.error, color: Colors.red.shade400, size: 40),
              ),
            ),
            ...detections.map((m) {
              final x = (m['x'] as num).toDouble();
              final y = (m['y'] as num).toDouble();
              final w = (m['w'] as num).toDouble();
              final h = (m['h'] as num).toDouble();
              return FractionallySizedBox(
                widthFactor: w,
                heightFactor: h,
                alignment: Alignment(-1 + x * 2 + w, -1 + y * 2 + h),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(width: 2.5, color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${m['label']} ${(m['score'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _DamageCard extends StatelessWidget {
  final String url;
  final List<Map<String, dynamic>> detections;
  final String? severityGrade;
  final String? location;
  final String? phenomenon;
  const _DamageCard({
    required this.url,
    required this.detections,
    this.severityGrade,
    this.location,
    this.phenomenon,
    this.onDelete,
  });
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: _DamagePreview(url: url, detections: detections),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (severityGrade != null && severityGrade!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '등급 ${severityGrade!}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${detections.length}개 감지',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: '삭제',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: onDelete,
                      ),
                  ],
                ),
                if ((location ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '위치: $location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if ((phenomenon ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '현상: $phenomenon',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
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

// ═══════════════════════════════════════════════════════════════
// Table Cell Widgets for the new table-based UI
// ═══════════════════════════════════════════════════════════════

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final int colspan;
  const _TableCell(this.text, {this.colspan = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Text(
        text.isEmpty ? '-' : text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
class _SurveyRowConfig {
  const _SurveyRowConfig({required this.key, required this.label, this.hint});

  final String key;
  final String label;
  final String? hint;
}

class _ConservationRowConfig {
  const _ConservationRowConfig({
    required this.key,
    required this.section,
    required this.part,
    this.noteHint,
    this.locationHint,
  });

  final String key;
  final String section;
  final String part;
  final String? noteHint;
  final String? locationHint;
}

// Heritage History Dialog - 기존이력확인 팝업
// ═══════════════════════════════════════════════════════════════

class HeritageHistoryDialog extends StatefulWidget {
  final String heritageId;
  final String heritageName;
  const HeritageHistoryDialog({
    super.key,
    required this.heritageId,
    required this.heritageName,
  });

  @override
  State<HeritageHistoryDialog> createState() => _HeritageHistoryDialogState();
}

class _HeritageHistoryDialogState extends State<HeritageHistoryDialog> {
  static const List<_SurveyRowConfig> _surveyRowConfigs = [
    _SurveyRowConfig(key: 'structure', label: '구조부'),
    _SurveyRowConfig(key: 'wall', label: '축석(벽체부)'),
    _SurveyRowConfig(key: 'roof', label: '지붕부'),
  ];
  static const List<_ConservationRowConfig> _conservationRowConfigs = [
    _ConservationRowConfig(key: 'structure', section: '구조부', part: '기단'),
    _ConservationRowConfig(key: 'roof', section: '지붕부', part: '—'),
  ];
  String _selectedYear = '2024년 조사';
  final List<_HistoryImage> _locationImages = [];
  final List<_HistoryImage> _currentPhotos = [];
  final List<_HistoryImage> _damagePhotos = [];
  late final Map<String, TextEditingController> _surveyControllers;
  late final Map<String, TextEditingController> _conservationPartControllers;
  late final Map<String, TextEditingController> _conservationNoteControllers;
  late final Map<String, TextEditingController>
  _conservationLocationControllers;
  final TextEditingController _fireSafetyPartController =
      TextEditingController();
  final TextEditingController _fireSafetyNoteController =
      TextEditingController();
  final TextEditingController _electricalPartController =
      TextEditingController();
  final TextEditingController _electricalNoteController =
      TextEditingController();
  Map<String, dynamic> _managementYears = {};
  bool _isEditable = false;
  bool _isSaving = false;
  Presence? _mgmtFireSafety;
  Presence? _mgmtElectrical;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _managementSub;

  Future<void> _addPhoto(List<_HistoryImage> target) async {
    if (!_isEditable) return;
    final picked = await ImageAcquire.pick(context);
    if (picked == null) return;
    final (bytes, _) = picked;
    if (!mounted) return;
    setState(() => target.add(_HistoryImage.memory(bytes)));
  }

  @override
  void initState() {
    super.initState();
    _surveyControllers = {
      for (final row in _surveyRowConfigs) row.key: TextEditingController(),
    };
    _conservationPartControllers = {
      for (final row in _conservationRowConfigs)
        row.key: TextEditingController(),
    };
    _conservationNoteControllers = {
      for (final row in _conservationRowConfigs)
        row.key: TextEditingController(),
    };
    _conservationLocationControllers = {
      for (final row in _conservationRowConfigs)
        row.key: TextEditingController(),
    };
    _surveyControllers['structure']?.text = '이하 내용 1.1 총괄사항 참고';
    _surveyControllers['wall']?.text = '—';
    _surveyControllers['roof']?.text = '이하 내용 1.1 총괄사항 참고';
    _conservationPartControllers['structure']?.text = '기단';
    _conservationPartControllers['roof']?.text = '—';
    _conservationNoteControllers['structure']?.text = '이하 내용 1.2 보존사항 참고';
    _conservationNoteControllers['roof']?.text = '* 필요시 사진 보이기';
    _conservationLocationControllers['structure']?.text = '7,710';
    _conservationLocationControllers['roof']?.text = '';
    _fireSafetyPartController.text = '방재/피뢰설비';
    _electricalPartController.text = '전선/조명 등';

    _managementSub = FirebaseFirestore.instance
        .collection('heritage_management')
        .doc(widget.heritageId)
        .snapshots()
        .listen((doc) {
          if (!mounted) return;
          final data = doc.data() ?? {};
          var years = _mapFrom(data['years']);
          if (years.isEmpty) {
            final legacyFire = data['fireSafety'];
            final legacyElectrical = data['electrical'];
            if (legacyFire != null || legacyElectrical != null) {
              years[_currentYearKey] = {
                if (legacyFire != null) 'fireSafety': {'exists': legacyFire},
                if (legacyElectrical != null)
                  'electrical': {'exists': legacyElectrical},
              };
            }
          }

          final yearData = _mapFrom(years[_currentYearKey]);
          final fireSection = _mapFrom(yearData['fireSafety']);
          final electricalSection = _mapFrom(yearData['electrical']);
          final firePresence = _presenceFromSection(fireSection);
          final electricalPresence = _presenceFromSection(electricalSection);
          final fireNote = _noteFromSection(fireSection);
          final electricalNote = _noteFromSection(electricalSection);

          final shouldHydrate = !_isEditable;
          if (shouldHydrate) {
            _fireSafetyNoteController.text = fireNote;
            _electricalNoteController.text = electricalNote;
            _populateSurveyFields(yearData);
            _populateConservationFields(yearData);
          }

          final locationImages = _decodePhotoList(yearData['locationPhotos']);
          final currentImages = _decodePhotoList(yearData['currentPhotos']);
          final damageImages = _decodePhotoList(yearData['damagePhotos']);

          setState(() {
            _managementYears = years;
            _mgmtFireSafety = firePresence;
            _mgmtElectrical = electricalPresence;
            if (shouldHydrate) {
              _locationImages
                ..clear()
                ..addAll(locationImages);
              _currentPhotos
                ..clear()
                ..addAll(currentImages);
              _damagePhotos
                ..clear()
                ..addAll(damageImages);
            }
          });
        });
  }

  Presence? _parsePresence(dynamic v) {
    if (v == null) return null;
    if (v is Presence) return v;
    if (v is bool) return v ? Presence.yes : Presence.no;
    if (v is String) {
      final normalized = v.trim().toLowerCase();
      if (normalized == 'yes' || normalized == 'y' || normalized == 'true') {
        return Presence.yes;
      }
      if (normalized == 'no' || normalized == 'n' || normalized == 'false') {
        return Presence.no;
      }
    }
    return null;
  }

  String get _currentYearKey {
    final match = RegExp(r'\d{4}').firstMatch(_selectedYear);
    return match?.group(0) ?? _selectedYear;
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((key, dynamic val) => MapEntry(key.toString(), val));
    }
    return {};
  }

  Map<String, dynamic> _yearData(String yearKey) =>
      _mapFrom(_managementYears[yearKey]);

  Map<String, dynamic> _sectionData(
    Map<String, dynamic> yearData,
    String key,
  ) => _mapFrom(yearData[key]);

  Presence? _presenceFromSection(Map<String, dynamic> section) {
    final source = section['exists'] ?? section['presence'] ?? section['value'];
    return _parsePresence(source);
  }

  String _noteFromSection(Map<String, dynamic> section) {
    final note = section['note'];
    if (note is String) return note;
    return '';
  }

  void _populateSurveyFields(
    Map<String, dynamic> yearData, {
    bool force = false,
  }) {
    if (!force && _isEditable) return;
    final surveyData = _mapFrom(yearData['survey']);
    for (final row in _surveyRowConfigs) {
      final controller = _surveyControllers[row.key];
      if (controller != null) {
        final value = surveyData[row.key];
        if (value is String) {
          controller.text = value;
        }
      }
    }
  }

  void _populateConservationFields(
    Map<String, dynamic> yearData, {
    bool force = false,
  }) {
    if (!force && _isEditable) return;
    final conservationData = _mapFrom(yearData['conservation']);
    for (final row in _conservationRowConfigs) {
      final rowData = _mapFrom(conservationData[row.key]);
      final note = rowData['note'];
      final location = rowData['photoLocation'] ?? rowData['location'];
      final noteController = _conservationNoteControllers[row.key];
      final locationController = _conservationLocationControllers[row.key];
      if (noteController != null && note is String) {
        noteController.text = note;
      }
      if (locationController != null && location is String) {
        locationController.text = location;
      }
    }
  }

  List<_HistoryImage> _decodePhotoList(dynamic raw) {
    if (raw is List) {
      final result = <_HistoryImage>[];
      for (final item in raw) {
        if (item is String && item.isNotEmpty) {
          result.add(_HistoryImage.network(item));
        } else if (item is Map) {
          final mapItem = _mapFrom(item);
          final url = mapItem['url'];
          final bytesBase64 = mapItem['bytes'];
          if (url is String && url.isNotEmpty) {
            result.add(_HistoryImage.network(url));
          } else if (bytesBase64 is String && bytesBase64.isNotEmpty) {
            try {
              final bytes = base64Decode(bytesBase64);
              result.add(_HistoryImage.memory(bytes));
            } catch (e) {
              debugPrint('Failed to decode base64 image: $e');
            }
          }
        }
      }
      return result;
    }
    return [];
  }

  void _refreshManagementFields({bool overrideNotes = false}) {
    final yearData = _yearData(_currentYearKey);
    final fireSection = _sectionData(yearData, 'fireSafety');
    final electricalSection = _sectionData(yearData, 'electrical');
    final firePresence = _presenceFromSection(fireSection);
    final electricalPresence = _presenceFromSection(electricalSection);
    final fireNote = _noteFromSection(fireSection);
    final electricalNote = _noteFromSection(electricalSection);
    final shouldHydrate = overrideNotes || !_isEditable;

    if (shouldHydrate) {
      _fireSafetyNoteController.text = fireNote;
      _electricalNoteController.text = electricalNote;
      _populateSurveyFields(yearData, force: true);
      _populateConservationFields(yearData, force: true);
    }

    final locationImages = _decodePhotoList(yearData['locationPhotos']);
    final currentImages = _decodePhotoList(yearData['currentPhotos']);
    final damageImages = _decodePhotoList(yearData['damagePhotos']);

    setState(() {
      _mgmtFireSafety = firePresence;
      _mgmtElectrical = electricalPresence;
      if (shouldHydrate) {
        _locationImages
          ..clear()
          ..addAll(locationImages);
        _currentPhotos
          ..clear()
          ..addAll(currentImages);
        _damagePhotos
          ..clear()
          ..addAll(damageImages);
      }
    });
  }

  Timer? _saveDebounce;
  bool _hasUnsavedChanges = false;

  void _scheduleSave() {
    if (!_isEditable) return;
    _hasUnsavedChanges = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _saveNow();
      } catch (e, st) {
        debugPrint('Failed to auto-save management data: $e');
        if (kDebugMode) {
          debugPrint(st.toString());
        }
      }
    });
  }

  Future<void> _saveNow() async {
    _saveDebounce?.cancel();
    final yearKey = _currentYearKey;
    if (yearKey.isEmpty) return;

    String trimText(TextEditingController controller) => controller.text.trim();

    final surveyData = <String, dynamic>{
      for (final row in _surveyRowConfigs)
        row.key: trimText(_surveyControllers[row.key]!),
    };

    final conservationData = <String, dynamic>{
      for (final row in _conservationRowConfigs)
        row.key: {
          'section': row.section,
          'part': trimText(_conservationPartControllers[row.key]!),
          'note': trimText(_conservationNoteControllers[row.key]!),
          'photoLocation': trimText(_conservationLocationControllers[row.key]!),
        },
    };

    Map<String, dynamic> presencePayload(
      Presence? presence,
      TextEditingController noteController,
      TextEditingController partController, {
      required String section,
    }) {
      final value = <String, dynamic>{
        'section': section,
        'part': trimText(partController),
        'note': trimText(noteController),
        'presence': presence == null
            ? null
            : (presence == Presence.yes ? 'yes' : 'no'),
        'exists': presence == null
            ? null
            : (presence == Presence.yes ? 'yes' : 'no'),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      return value;
    }

    final fireSafetyData = presencePayload(
      _mgmtFireSafety,
      _fireSafetyNoteController,
      _fireSafetyPartController,
      section: '소방 및 안전관리',
    );
    final electricalData = presencePayload(
      _mgmtElectrical,
      _electricalNoteController,
      _electricalPartController,
      section: '전기시설',
    );

    final timestamp = FieldValue.serverTimestamp();
    final docRef = FirebaseFirestore.instance
        .collection('heritage_management')
        .doc(widget.heritageId);

    await docRef.set({
      'years.$yearKey.survey': surveyData,
      'years.$yearKey.conservation': conservationData,
      'years.$yearKey.fireSafety': fireSafetyData,
      'years.$yearKey.electrical': electricalData,
      'years.$yearKey.updatedAt': timestamp,
      'heritageName': widget.heritageName,
      'updatedAt': timestamp,
    }, SetOptions(merge: true));

    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
      });
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _managementSub?.cancel();
    for (final controller in _surveyControllers.values) {
      controller.dispose();
    }
    for (final controller in _conservationPartControllers.values) {
      controller.dispose();
    }
    for (final controller in _conservationNoteControllers.values) {
      controller.dispose();
    }
    for (final controller in _conservationLocationControllers.values) {
      controller.dispose();
    }
    _fireSafetyPartController.dispose();
    _fireSafetyNoteController.dispose();
    _electricalPartController.dispose();
    _electricalNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String pageTitle = widget.heritageName.isNotEmpty
        ? widget.heritageName
        : '기존 이력';

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '기존 이력',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<String>(
                          value: _selectedYear,
                          items: const [
                            DropdownMenuItem(
                              value: '2024년 조사',
                              child: Text('2024년 조사'),
                            ),
                            DropdownMenuItem(
                              value: '2022년 조사',
                              child: Text('2022년 조사'),
                            ),
                            DropdownMenuItem(
                              value: '2020년 조사',
                              child: Text('2020년 조사'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedYear = v;
                              _isEditable = false;
                            });
                            _refreshManagementFields(overrideNotes: true);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const SizedBox(height: 16),
                    const _HistorySectionTitle('1.1 조사결과'),
                    const SizedBox(height: 8),
                    _buildSurveyTable(),
                    const SizedBox(height: 24),
                    const _HistorySectionTitle('1.2 보존사항'),
                    const SizedBox(height: 8),
                    _buildConservationTable(),
                    const SizedBox(height: 24),
                    const _HistorySectionTitle('1.3 관리사항'),
                    const SizedBox(height: 8),
                    _buildManagementTable(),
                    const SizedBox(height: 24),
                    const _HistorySectionTitle('1.4 위치현황'),
                    const SizedBox(height: 8),
                    _buildHistoryPhotoSection(
                      title: '위치 도면/위성자료 등록',
                      description: '위치 및 도면 자료를 업로드하세요.',
                      photos: _locationImages,
                      onAdd: () => _addPhoto(_locationImages),
                    ),
                    const SizedBox(height: 24),
                    const _HistorySectionTitle('1.5 현황사진'),
                    const SizedBox(height: 8),
                    _buildHistoryPhotoSection(
                      title: '현황 사진 등록',
                      description: '최근 촬영한 현황 사진을 관리합니다.',
                      photos: _currentPhotos,
                      onAdd: () => _addPhoto(_currentPhotos),
                    ),
                    const SizedBox(height: 24),
                    const _HistorySectionTitle('1.6 손상부 조사'),
                    _buildHistoryPhotoSection(
                      title: '손상부 사진 등록',
                      description:
                          '손상부 조사 결과를 사진과 함께 보관합니다. 직전 조사 대비 손상부 변화를 비교하세요.',
                      photos: _damagePhotos,
                      onAdd: () => _addPhoto(_damagePhotos),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            _refreshManagementFields(overrideNotes: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('이력 데이터를 불러왔습니다')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 44),
                          ),
                          child: const Text('불러오기'),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 44),
                          ),
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isEditable
                              ? null
                              : () {
                                  setState(() => _isEditable = true);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 44),
                          ),
                          child: const Text('수정'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isEditable && !_isSaving
                              ? () async {
                                  FocusScope.of(context).unfocus();
                                  setState(() => _isSaving = true);
                                  try {
                                    await _saveNow();
                                    if (!mounted) return;
                                    setState(() {
                                      _isEditable = false;
                                      _isSaving = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('변경사항이 저장되었습니다'),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    setState(() => _isSaving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('저장에 실패했습니다: $e')),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 44),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('저장'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper functions for editable cells
  Widget _editableCell(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: TextFormField(
        controller: controller,
        enabled: _isEditable,
        minLines: 1,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint ?? '입력하세요',
          border: const OutlineInputBorder(),
          disabledBorder: const OutlineInputBorder(),
          fillColor: _isEditable ? Colors.white : Colors.grey.shade100,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        onChanged: (_) {
          if (_isEditable) _scheduleSave();
        },
      ),
    );
  }

  Widget _buildSurveyTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(3)},
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [
            _HistoryTableCell('구분', isHeader: true),
            _HistoryTableCell('내용', isHeader: true),
          ],
        ),
        for (final row in _surveyRowConfigs)
          TableRow(
            children: [
              _HistoryTableCell(row.label),
              _editableCell(
                _surveyControllers[row.key]!,
                hint: '예: 이하 내용 1.1 총괄사항 참고',
                maxLines: 2,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildConservationTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(2.5),
        3: FlexColumnWidth(1),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [
            _HistoryTableCell('구분', isHeader: true),
            _HistoryTableCell('부재', isHeader: true),
            _HistoryTableCell('조사내용(현상)', isHeader: true),
            _HistoryTableCell('사진/위치', isHeader: true),
          ],
        ),
        for (final row in _conservationRowConfigs)
          TableRow(
            children: [
              _HistoryTableCell(row.section),
              _editableCell(
                _conservationPartControllers[row.key]!,
                hint: '예: 기단',
              ),
              _editableCell(
                _conservationNoteControllers[row.key]!,
                hint: '예: 균열/박락 등',
                maxLines: 3,
              ),
              _editableCell(
                _conservationLocationControllers[row.key]!,
                hint: '예: 7,710',
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildManagementTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(2.5),
        3: FlexColumnWidth(0.6),
        4: FlexColumnWidth(0.6),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [
            _HistoryTableCell('구분', isHeader: true),
            _HistoryTableCell('부재', isHeader: true),
            _HistoryTableCell('조사내용(현상)', isHeader: true),
            _HistoryTableCell('있음', isHeader: true),
            _HistoryTableCell('없음', isHeader: true),
          ],
        ),
        TableRow(
          children: [
            const _HistoryTableCell('소방 및 안전관리'),
            _editableCell(_fireSafetyPartController, hint: '예: 방재/피뢰설비'),
            _MgmtNoteCell(
              controller: _fireSafetyNoteController,
              enabled: _isEditable,
              onChanged: (value) {
                if (!_isEditable) return;
                _scheduleSave();
              },
            ),
            _MgmtRadioCell(
              enabled: _isEditable,
              groupValue: _mgmtFireSafety,
              target: Presence.yes,
              onChanged: (value) {
                if (!_isEditable) return;
                setState(() => _mgmtFireSafety = value);
                _scheduleSave();
              },
            ),
            _MgmtRadioCell(
              enabled: _isEditable,
              groupValue: _mgmtFireSafety,
              target: Presence.no,
              onChanged: (value) {
                if (!_isEditable) return;
                setState(() => _mgmtFireSafety = value);
                _scheduleSave();
              },
            ),
          ],
        ),
        TableRow(
          children: [
            const _HistoryTableCell('전기시설'),
            _editableCell(_electricalPartController, hint: '예: 전선/조명 등'),
            _MgmtNoteCell(
              controller: _electricalNoteController,
              enabled: _isEditable,
              onChanged: (value) {
                if (!_isEditable) return;
                _scheduleSave();
              },
            ),
            _MgmtRadioCell(
              enabled: _isEditable,
              groupValue: _mgmtElectrical,
              target: Presence.yes,
              onChanged: (value) {
                if (!_isEditable) return;
                setState(() => _mgmtElectrical = value);
                _scheduleSave();
              },
            ),
            _MgmtRadioCell(
              enabled: _isEditable,
              groupValue: _mgmtElectrical,
              target: Presence.no,
              onChanged: (value) {
                if (!_isEditable) return;
                setState(() => _mgmtElectrical = value);
                _scheduleSave();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistoryPhotoSection({
    required String title,
    required String description,
    required List<_HistoryImage> photos,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: photos.length + 1,
          itemBuilder: (context, index) {
            if (index == photos.length) {
              return _AddPhotoTile(onTap: onAdd);
            }
            final photo = photos[index];
            return _HistoryImageTile(
              image: photo,
              onRemove: () {
                setState(() => photos.removeAt(index));
              },
            );
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title 항목의 추가 기록 기능은 준비 중입니다.')),
              );
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              '더보기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

// 섹션 타이틀 (검은 배경)
class _HistorySectionTitle extends StatelessWidget {
  final String text;
  const _HistorySectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}

enum Presence { yes, no }

// 테이블 셀
class _HistoryTableCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final bool isRed;

  const _HistoryTableCell(
    this.text, {
    this.isHeader = false,
    this.isRed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isRed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _MgmtRadioCell extends StatelessWidget {
  final Presence? groupValue;
  final Presence target;
  final ValueChanged<Presence> onChanged;
  final bool enabled;

  const _MgmtRadioCell({
    super.key,
    required this.groupValue,
    required this.target,
    required this.onChanged,
    this.enabled = false, // ✅ 기본값을 false로 변경 (기본 잠금)
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled, // ✅ enabled가 false면 모든 터치 이벤트 무시
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5, // ✅ 시각적으로 비활성화 표시
        child: InkWell(
          onTap: enabled ? () => onChanged(target) : null,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: Transform.scale(
              scale: 1.3,
              child: Radio<Presence>(
                value: target,
                groupValue: groupValue,
                onChanged: enabled
                    ? (value) {
                        if (value != null) {
                          onChanged(value);
                        }
                      }
                    : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MgmtNoteCell extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _MgmtNoteCell({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: IgnorePointer(
        ignoring: !enabled, // ✅ enabled가 false면 모든 터치 이벤트 무시
        child: Opacity(
          opacity: enabled ? 1.0 : 0.6, // ✅ 시각적으로 비활성화 표시
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            minLines: 1,
            maxLines: 3,
            onChanged: enabled ? onChanged : null,
            style: TextStyle(
              color: enabled ? Colors.black87 : Colors.grey.shade600,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: '조사내용을 입력하세요',
              border: const OutlineInputBorder(),
              disabledBorder: const OutlineInputBorder(),
              fillColor: enabled ? Colors.white : Colors.grey.shade100,
              filled: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
          color: Colors.grey.shade100,
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate, size: 32, color: Colors.black54),
              SizedBox(height: 6),
              Text(
                '사진 추가',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryImageTile extends StatelessWidget {
  final _HistoryImage image;
  final VoidCallback onRemove;
  const _HistoryImageTile({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Ink.image(
            image: image.provider,
            fit: BoxFit.cover,
            child: InkWell(onTap: () => _showPreview(context)),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: AspectRatio(
            aspectRatio: 1,
            child: Image(image: image.provider, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _HistoryImage {
  const _HistoryImage._(this.bytes, this.url);
  factory _HistoryImage.memory(Uint8List bytes) => _HistoryImage._(bytes, null);
  factory _HistoryImage.network(String url) => _HistoryImage._(null, url);

  final Uint8List? bytes;
  final String? url;

  ImageProvider get provider =>
      bytes != null ? MemoryImage(bytes!) : CachedNetworkImageProvider(url!);
}

Widget _buildPhotoSection({
  required String title,
  required String description,
  required List<_HistoryImage> photos,
  required VoidCallback onAdd,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('추가'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        if (photos.isEmpty)
          const Text('등록된 사진이 없습니다.', style: TextStyle(color: Colors.grey))
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final img = photos[i];
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image(image: img.provider, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// DamageDetectionDialog - AI 손상부 조사 다이얼로그
// ═══════════════════════════════════════════════════════════════

class DamageDetectionDialog extends StatefulWidget {
  const DamageDetectionDialog({
    super.key,
    required this.aiService,
    this.autoCapture = false,
  });

  final AiDetectionService aiService;
  final bool autoCapture;

  @override
  State<DamageDetectionDialog> createState() => _DamageDetectionDialogState();
}

class _DamageDetectionDialogState extends State<DamageDetectionDialog> {
  Uint8List? _imageBytes;
  List<Map<String, dynamic>> _detections = [];
  bool _loading = false;

  String? _selectedLabel;
  double? _selectedConfidence;
  String? _autoGrade;
  String? _autoExplanation;
  double? _imageWidth;
  double? _imageHeight;

  // 전년도 사진 관련
  String? _previousYearImageUrl;
  bool _loadingPreviousPhoto = false;
  final _fb = FirebaseService();

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _partController = TextEditingController();
  final TextEditingController _opinionController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  String _severityGrade = 'A';

  @override
  void initState() {
    super.initState();
    if (widget.autoCapture) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickImageAndDetect();
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _partController.dispose();
    _opinionController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    super.dispose();
  }

  Future<void> _pickImageAndDetect() async {
    final picked = await ImageAcquire.pick(context);
    if (picked == null) return;
    final (bytes, sizeGetter) = picked;
    final ui.Size size = await sizeGetter();
    setState(() {
      _loading = true;
      _imageBytes = bytes;
      _imageWidth = size.width;
      _imageHeight = size.height;
      _detections = [];
      _selectedLabel = null;
      _selectedConfidence = null;
      _autoGrade = null;
      _autoExplanation = null;
    });

    final detectionResult = await widget.aiService.detect(bytes);
    if (!mounted) return;

    final sorted = List<Map<String, dynamic>>.from(detectionResult.detections)
      ..sort(
        (a, b) =>
            ((b['score'] as num?) ?? 0).compareTo(((a['score'] as num?) ?? 0)),
      );
    final normalized = _normalizeDetections(sorted);

    setState(() {
      _loading = false;
      _detections = normalized;
      if (_detections.isNotEmpty) {
        _selectedLabel = _detections.first['label'] as String?;
        _selectedConfidence = (_detections.first['score'] as num?)?.toDouble();
      }
      final normalizedGrade = detectionResult.grade?.toUpperCase();
      _autoGrade = normalizedGrade;
      _autoExplanation = detectionResult.explanation;
      if (normalizedGrade != null &&
          ['A', 'B', 'C', 'D', 'E', 'F'].contains(normalizedGrade)) {
        _severityGrade = normalizedGrade;
      }
    });
  }

  Future<void> _handleSave() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진을 먼저 촬영하거나 업로드하세요.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('손상 감지 결과 저장'),
        content: const Text('현재 입력한 조사 내용을 저장하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = DamageDetectionResult(
      imageBytes: _imageBytes!,
      detections: _detections,
      selectedLabel: _selectedLabel,
      selectedConfidence: _selectedConfidence,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      damagePart: _partController.text.trim().isEmpty
          ? null
          : _partController.text.trim(),
      temperature: _temperatureController.text.trim().isEmpty
          ? null
          : _temperatureController.text.trim(),
      humidity: _humidityController.text.trim().isEmpty
          ? null
          : _humidityController.text.trim(),
      opinion: _opinionController.text.trim().isEmpty
          ? null
          : _opinionController.text.trim(),
      severityGrade: _severityGrade,
      autoGrade: _autoGrade,
      autoExplanation: _autoExplanation,
    );

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF3B4C59),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '손상부 조사',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // 메인 스크롤 영역
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1️⃣ 사진 비교 섹션
                    _buildPhotoComparisonSection(),
                    const SizedBox(height: 20),

                    // 2️⃣ 손상 감지 결과 (사진이 있을 때만)
                    if (_imageBytes != null && _detections.isNotEmpty)
                      _buildDetectionResultSection(),
                    if (_imageBytes != null && _detections.isNotEmpty)
                      const SizedBox(height: 20),

                    // 3️⃣ 손상 정보 입력
                    _buildInfoInputSection(),
                    const SizedBox(height: 20),

                    // 4️⃣ 손상 분류
                    _buildDamageClassificationSection(),
                    const SizedBox(height: 20),

                    // 5️⃣ 손상 등급
                    _buildGradeSection(),
                    const SizedBox(height: 20),

                    // 6️⃣ 조사자 의견
                    _buildOpinionSection(),
                  ],
                ),
              ),
            ),

            // 하단 고정 버튼
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: const Color(0xFFE2E6EA))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4C8BF5),
                      side: const BorderSide(color: Color(0xFF4C8BF5)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C8BF5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('저장'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Section Builders
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPhotoComparisonSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.photo_camera, size: 20, color: const Color(0xFF212529)),
                const SizedBox(width: 8),
                Text(
                  '사진 비교',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212529),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '전년도 조사 사진',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6C757D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E6EA)),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '이번 조사 사진',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6C757D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _loading ? null : _pickImageAndDetect,
                            child: Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: _imageBytes == null
                                    ? const Color(0xFFFAFAFA)
                                    : Colors.black,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _imageBytes == null
                                      ? const Color(0xFFE2E6EA)
                                      : const Color(0xFF4C8BF5),
                                  width: 2,
                                ),
                              ),
                              child: _imageBytes == null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 48,
                                          color: const Color(0xFF4C8BF5),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '사진 촬영/업로드',
                                          style: TextStyle(
                                            color: const Color(0xFF4C8BF5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.memory(
                                            _imageBytes!,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        if (_loading)
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionResultSection() {
    // Group detections by label and count
    final Map<String, int> labelCounts = {};
    for (final det in _detections) {
      final label = det['label'] as String? ?? '미분류';
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: const Color(0xFF212529)),
                const SizedBox(width: 8),
                Text(
                  'AI 손상 감지 결과',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212529),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '총 ${_detections.length}개 감지',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: labelCounts.entries.map((entry) {
                final label = entry.key;
                final count = entry.value;
                Color chipColor;

                // Assign colors based on damage type
                if (label.contains('균열') || label.contains('crack')) {
                  chipColor = const Color(0xFFEF4444);
                } else if (label.contains('박락') || label.contains('박리')) {
                  chipColor = const Color(0xFFF59E0B);
                } else if (label.contains('변색') || label.contains('오염')) {
                  chipColor = const Color(0xFF3B82F6);
                } else {
                  chipColor = const Color(0xFF4C8BF5);
                }

                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: chipColor,
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(label),
                  backgroundColor: chipColor.withValues(alpha: 0.1),
                  side: BorderSide(color: chipColor),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 20, color: const Color(0xFF212529)),
                const SizedBox(width: 8),
                Text(
                  '손상 정보 입력',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212529),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: '손상 위치',
                    hintText: '예: 남향 2번 평주',
                    prefixIcon: Icon(Icons.location_on, color: const Color(0xFF4C8BF5)),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _partController,
                  decoration: InputDecoration(
                    labelText: '손상 부위',
                    hintText: '예: 기둥 - 상부',
                    prefixIcon: Icon(Icons.build, color: const Color(0xFF4C8BF5)),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _temperatureController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '온도(℃)',
                          hintText: '예: 23',
                          prefixIcon: Icon(Icons.thermostat, color: const Color(0xFF4C8BF5)),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _humidityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '습도(%)',
                          hintText: '예: 55',
                          prefixIcon: Icon(Icons.water_drop, color: const Color(0xFF4C8BF5)),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDamageClassificationSection() {
    // Extract unique damage types from detections
    final Set<String> damageTypes = {};
    for (final det in _detections) {
      final label = det['label'] as String? ?? '';
      if (label.contains('균열') || label.contains('crack')) {
        damageTypes.add('구조적 손상');
      }
      if (label.contains('박락') || label.contains('박리') || label.contains('탈락')) {
        damageTypes.add('물리적 손상');
      }
      if (label.contains('변색') || label.contains('오염') || label.contains('생물')) {
        damageTypes.add('생물·화학적 손상');
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.category, size: 20, color: const Color(0xFF212529)),
                const SizedBox(width: 8),
                Text(
                  '손상 분류',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212529),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (damageTypes.isEmpty)
                  Text(
                    '손상 감지 결과에서 분류 정보를 추출할 수 없습니다.',
                    style: TextStyle(color: const Color(0xFF6C757D)),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildClassificationChip(
                        '구조적 손상',
                        '균열, 파손 등',
                        damageTypes.contains('구조적 손상'),
                        const Color(0xFFEF4444),
                      ),
                      _buildClassificationChip(
                        '물리적 손상',
                        '박락, 박리 등',
                        damageTypes.contains('물리적 손상'),
                        const Color(0xFFF59E0B),
                      ),
                      _buildClassificationChip(
                        '생물·화학적 손상',
                        '변색, 오염 등',
                        damageTypes.contains('생물·화학적 손상'),
                        const Color(0xFF3B82F6),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationChip(String title, String subtitle, bool isActive, Color color) {
    return FilterChip(
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isActive ? color : const Color(0xFF212529),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? color.withValues(alpha: 0.8) : const Color(0xFF6C757D),
            ),
          ),
        ],
      ),
      selected: isActive,
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      side: BorderSide(
        color: isActive ? color : const Color(0xFFE2E6EA),
        width: isActive ? 2 : 1,
      ),
      onSelected: (_) {
        // Read-only for now, just shows detected types
      },
    );
  }

  Widget _buildGradeSection() {
    final grades = ['A', 'B', 'C', 'D', 'E', 'F'];
    final gradeColors = {
      'A': const Color(0xFF10B981),
      'B': const Color(0xFF3B82F6),
      'C': const Color(0xFFF59E0B),
      'D': const Color(0xFFEF4444),
      'E': const Color(0xFFEF4444),
      'F': const Color(0xFFEF4444),
    };
    final gradeDescriptions = {
      'A': '양호',
      'B': '경미한 손상',
      'C': '보통 손상',
      'D': '심각한 손상',
      'E': '매우 심각',
      'F': '위험',
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.grade, size: 20, color: const Color(0xFF212529)),
                const SizedBox(width: 8),
                Text(
                  '손상 등급',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212529),
                  ),
                ),
                if (_autoGrade != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: gradeColors[_autoGrade] ?? const Color(0xFF4C8BF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'AI 추천: $_autoGrade',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: grades.map((grade) {
                    final isSelected = _severityGrade == grade;
                    final color = gradeColors[grade] ?? const Color(0xFF4C8BF5);

                    return InkWell(
                      onTap: () => setState(() => _severityGrade = grade),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? color : const Color(0xFFE2E6EA),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(
                              value: grade,
                              groupValue: _severityGrade,
                              onChanged: (val) {
                                if (val != null) setState(() => _severityGrade = val);
                              },
                              activeColor: color,
                            ),
                            const SizedBox(width: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  grade,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? color : const Color(0xFF212529),
                                  ),
                                ),
                                Text(
                                  gradeDescriptions[grade] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? color.withValues(alpha: 0.8) : const Color(0xFF6C757D),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_autoExplanation != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F1FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4C8BF5).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 20, color: const Color(0xFF4C8BF5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _autoExplanation!,
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF212529),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpinionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.rate_review, size: 20, color: const Color(0xFF212529)),
                const SizedBox(width: 8),
                Text(
                  '조사자 의견',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212529),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _opinionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '손상 상태에 대한 의견이나 추가 조치 사항을 입력하세요...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: _imageBytes == null
                ? const Center(child: Text('촬영된 이미지가 없습니다.'))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiSection() {
    final uniqueLabels = _detections
        .map((e) => e['label'] as String? ?? '미분류')
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI 예측 결과',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (_detections.isEmpty)
          const Text('예측 데이터를 가져오지 못했습니다. 필요 시 직접 입력하세요.'),
        ..._detections.map((det) {
          final label = det['label'] as String? ?? '미분류';
          final score = (det['score'] as num?)?.toDouble() ?? 0;
          final percent = (score * 100).toStringAsFixed(1);
          final isPrimary = label == _selectedLabel;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $label (${percent}%)',
              style: TextStyle(
                color: isPrimary ? Colors.redAccent : Colors.black87,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedLabel,
          decoration: const InputDecoration(
            labelText: '결과 수정',
            border: OutlineInputBorder(),
          ),
          items: uniqueLabels
              .map(
                (label) => DropdownMenuItem(value: label, child: Text(label)),
              )
              .toList(),
          onChanged: (val) {
            setState(() {
              _selectedLabel = val;
              final match = _detections.firstWhere(
                (e) => (e['label'] as String?) == val,
                orElse: () => const {},
              );
              _selectedConfidence =
                  (match['score'] as num?)?.toDouble() ?? _selectedConfidence;
            });
          },
        ),
        if (_autoGrade != null) ...[
          const SizedBox(height: 16),
          _buildGradeSummary(),
        ],
      ],
    );
  }

  Widget _infoField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSummary() {
    final grade = (_autoGrade ?? '').toUpperCase();
    final explanation = _autoExplanation ?? '추가 설명이 제공되지 않았습니다.';

    Color background;
    switch (grade) {
      case 'D':
        background = Colors.red.shade100;
        break;
      case 'C':
        background = Colors.orange.shade100;
        break;
      case 'B':
        background = Colors.blue.shade100;
        break;
      default:
        background = Colors.green.shade100;
    }

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              grade.isEmpty ? '?' : grade,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              explanation,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _normalizeDetections(
    List<Map<String, dynamic>> detections,
  ) {
    final width = _imageWidth;
    final height = _imageHeight;
    if (width == null || height == null || width == 0 || height == 0) {
      return detections
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    double clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

    return detections
        .map((det) {
          final mapped = Map<String, dynamic>.from(det);
          if (!(mapped.containsKey('x') &&
              mapped.containsKey('y') &&
              mapped.containsKey('w') &&
              mapped.containsKey('h'))) {
            final bbox = (mapped['bbox'] as List?)?.cast<num>();
            if (bbox != null && bbox.length == 4) {
              final x1 = bbox[0].toDouble();
              final y1 = bbox[1].toDouble();
              final x2 = bbox[2].toDouble();
              final y2 = bbox[3].toDouble();
              final w = (x2 - x1).clamp(0, width).toDouble();
              final h = (y2 - y1).clamp(0, height).toDouble();
              mapped['x'] = clamp01(x1 / width);
              mapped['y'] = clamp01(y1 / height);
              mapped['w'] = clamp01(w / width);
              mapped['h'] = clamp01(h / height);
            }
          }
          return mapped;
        })
        .toList(growable: false);
  }
}

class DamageDetectionResult {
  DamageDetectionResult({
    required this.imageBytes,
    required this.detections,
    this.selectedLabel,
    this.selectedConfidence,
    this.location,
    this.damagePart,
    this.temperature,
    this.humidity,
    this.opinion,
    this.severityGrade,
    this.autoGrade,
    this.autoExplanation,
  });

  final Uint8List imageBytes;
  final List<Map<String, dynamic>> detections;
  final String? selectedLabel;
  final double? selectedConfidence;
  final String? location;
  final String? damagePart;
  final String? temperature;
  final String? humidity;
  final String? opinion;
  final String? severityGrade;
  final String? autoGrade;
  final String? autoExplanation;

  Map<String, dynamic> toDetailInputs() {
    return {
      if (damagePart != null) 'damagePart': damagePart,
      if (temperature != null) 'temperature': temperature,
      if (humidity != null) 'humidity': humidity,
      if (selectedLabel != null) 'selectedLabel': selectedLabel,
      if (selectedConfidence != null) 'selectedConfidence': selectedConfidence,
      if (autoGrade != null) 'autoGrade': autoGrade,
      if (autoExplanation != null) 'autoExplanation': autoExplanation,
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// DeepDamageInspectionDialog - 손상부 조사 (심화조사)
// ═══════════════════════════════════════════════════════════════

class DeepDamageInspectionDialog extends StatefulWidget {
  const DeepDamageInspectionDialog({super.key});

  @override
  State<DeepDamageInspectionDialog> createState() =>
      _DeepDamageInspectionDialogState();
}

class _DeepDamageInspectionDialogState
    extends State<DeepDamageInspectionDialog> {
  // 더미 이미지 URL (손상부 사진)
  final String damageImageUrl =
      'https://images.unsplash.com/photo-1541888946425-d81bb19240f5?w=800';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                '손상부 조사 (심화조사)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // 스크롤 가능 영역 전체
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 손상 감지 이미지 + 박스 표시
                      Container(
                        height: 260,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black12,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: damageImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Shimmer.fromColors(
                                  baseColor: Colors.grey.shade300,
                                  highlightColor: Colors.grey.shade100,
                                  child: Container(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 손상 박스들
                            Positioned(
                              left: 30,
                              top: 50,
                              child: _damageBox('갈라짐', Colors.yellow),
                            ),
                            Positioned(
                              right: 50,
                              top: 40,
                              child: _damageBox('충해흔', Colors.orange),
                            ),
                            Positioned(
                              left: 80,
                              bottom: 40,
                              child: _damageBox('변색', Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 손상유형 표
                      const Text(
                        '손상 유형 및 물리 정보',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade400),
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1),
                          3: FlexColumnWidth(1.2),
                        },
                        children: [
                          _tableHeader(['손상유형', '구조', '물리', '생물·화학']),
                          _tableRow(['비중', '-', '-', '-']),
                          _tableRow(['함수율', '-', '-', '-']),
                          _tableRow(['공극률', '-', '-', '-']),
                          _tableRow(['압축강도', '-', '-', '-']),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 추가 정보 섹션
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '조사자 의견',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: '손상 상태 및 보수 의견을 입력하세요',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // 버튼 영역 (스크롤 하단)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // TODO: 등급 산출 로직
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('등급 산출 기능 준비 중')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade300,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 44),
                    ),
                    child: const Text('등급 산출'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: 저장 로직
                      Navigator.pop(context, {'saved': true});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 44),
                    ),
                    child: const Text('저장'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 44),
                    ),
                    child: const Text('취소'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 테이블 헤더
  TableRow _tableHeader(List<String> titles) => TableRow(
    decoration: BoxDecoration(color: Colors.grey.shade200),
    children: titles
        .map(
          (t) => Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                t,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        )
        .toList(),
  );

  // 테이블 행
  TableRow _tableRow(List<String> data) => TableRow(
    children: data
        .map(
          (d) => Padding(
            padding: const EdgeInsets.all(8),
            child: Center(child: Text(d)),
          ),
        )
        .toList(),
  );

  // 손상 박스 위젯
  Widget _damageBox(String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2.5),
            color: color.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
