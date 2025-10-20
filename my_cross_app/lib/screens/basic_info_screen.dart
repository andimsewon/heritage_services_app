import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/heritage_api.dart';
import '../env.dart';
import '../services/firebase_service.dart';
import '../services/ai_detection_service.dart';
import '../services/image_acquire.dart';

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
    final pair = await ImageAcquire.pick(context);
    if (pair == null) return;
    final (bytes, sizeGetter) = pair;

    // AI 분석 호출 (HTTP → 실패 시 더미)
    final detections = await _ai.detect(bytes);

    // 1차 확인 다이얼로그
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('손상 감지 결과 확인'),
        content: const Text('감지 결과를 저장하시겠습니까? (세부는 다음 단계에서 입력)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('계속'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    // 2차 세부 입력
    if (!mounted) return;
    final detail = await _askDamageDetail(context);

    // Firestore에 손상부 조사 문서 저장 (✅ imageBytes 사용)
    await _fb.addDamageSurvey(
      heritageId: heritageId,
      heritageName: _name,
      imageBytes: bytes,
      detections: detections,
      location: detail['location'] as String?,
      phenomenon: detail['phenomenon'] as String?,
      inspectorOpinion: detail['opinion'] as String?,
      severityGrade: detail['grade'] as String?,
      detailInputs: detail['inputs'] as Map<String, dynamic>?,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('손상부 조사 등록 완료')));
    }
  }


  Future<Map<String, Object?>> _askDamageDetail(BuildContext context) async {
    final location = TextEditingController();
    final phenomenon = TextEditingController();
    final opinion = TextEditingController();
    final grade = ValueNotifier<String>('A');

    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('손상 세부 입력'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: location,
                decoration: const InputDecoration(labelText: '손상 위치'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phenomenon,
                decoration: const InputDecoration(labelText: '손상 현상'),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder(
                valueListenable: grade,
                builder: (_, value, __) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: '부재 손상 등급'),
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('A')),
                    DropdownMenuItem(value: 'B', child: Text('B')),
                    DropdownMenuItem(value: 'C', child: Text('C')),
                    DropdownMenuItem(value: 'D', child: Text('D')),
                    DropdownMenuItem(value: 'E', child: Text('E')),
                    DropdownMenuItem(value: 'F', child: Text('F')),
                  ],
                  onChanged: (v) => grade.value = v ?? 'A',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: opinion,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '조사자 의견'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'location': location.text.trim(),
              'phenomenon': phenomenon.text.trim(),
              'opinion': opinion.text.trim(),
              'grade': grade.value,
              'inputs': <String, dynamic>{},
            }),
            child: const Text('등록'),
          ),
        ],
      ),
    );

    return result ?? <String, Object?>{};
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

  // 더 이상 사용하지 않음: _ai.detect 사용

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

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_name.isEmpty ? '기본개요' : _name),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.5),
                builder: (_) => HeritageHistoryDialog(heritageName: _name),
              );
            },
            icon: const Icon(Icons.history, size: 22),
            label: const Text('기존이력 확인'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrangeAccent,
              foregroundColor: Colors.white,
              elevation: 4,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ① 기본개요 섹션
          const Text(
            '기본개요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(2.5),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(2.5),
            },
            children: [
              TableRow(children: [
                _TableHeaderCell('국가유산명'),
                _TableCell(_name.isEmpty ? '미상' : _name),
                _TableHeaderCell('종목'),
                _TableCell(kind),
              ]),
              TableRow(children: [
                _TableHeaderCell('지정(등록)일'),
                _TableCell(asdt),
                _TableHeaderCell('소유자'),
                _TableCell(owner),
              ]),
              TableRow(children: [
                _TableHeaderCell('관리자'),
                _TableCell(admin),
                _TableHeaderCell('소재지'),
                _TableCell(lcto),
              ]),
              if (lcad.isNotEmpty)
                TableRow(children: [
                  _TableHeaderCell('소재지 상세'),
                  _TableCell(lcad, colspan: 3),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                ]),
            ],
          ),

          const SizedBox(height: 32),

          // ② 보존관리 이력 섹션
          const Text(
            '보존관리 이력',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '* 과거 최초 기록부터 현재까지 정비·보수·수리 내용',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '보존관리 이력 데이터가 없습니다.\n향후 업데이트 예정입니다.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),

          const Divider(height: 48),

          // ───── 문화유산 현황(사진)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  '문화유산 현황',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _addPhoto,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('사진 등록'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 150,
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

          const Divider(height: 32),

          // ───── 손상부 조사
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                const Text(
                  '손상부 조사',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _startDamageSurvey,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('촬영하여 조사'),
                ),
              ],
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                ),
            ],
          ),
          Text(meta, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DamagePreview extends StatelessWidget {
  final String url;
  final List<Map<String, dynamic>> detections; // label, score, x,y,w,h
  const _DamagePreview({required this.url, required this.detections});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(url, fit: BoxFit.contain),
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
      width: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
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
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (severityGrade != null && severityGrade!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.lightBlue.shade400),
                        ),
                        child: Text(
                          '등급 ${severityGrade!}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${detections.length}개 감지',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: '삭제',
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: onDelete,
                      ),
                  ],
                ),
                if ((location ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '위치: $location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if ((phenomenon ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '현상: $phenomenon',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
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
// Heritage History Dialog - 기존이력확인 팝업
// ═══════════════════════════════════════════════════════════════

class HeritageHistoryDialog extends StatefulWidget {
  final String heritageName;
  const HeritageHistoryDialog({super.key, required this.heritageName});

  @override
  State<HeritageHistoryDialog> createState() => _HeritageHistoryDialogState();
}

class _HeritageHistoryDialogState extends State<HeritageHistoryDialog> {
  String _selectedYear = '2024년 조사';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 + 드롭다운
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '기존 이력',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _selectedYear,
                    items: const [
                      DropdownMenuItem(value: '2024년 조사', child: Text('2024년 조사')),
                      DropdownMenuItem(value: '2022년 조사', child: Text('2022년 조사')),
                      DropdownMenuItem(value: '2020년 조사', child: Text('2020년 조사')),
                    ],
                    onChanged: (v) => setState(() => _selectedYear = v!),
                  ),
                ],
              ),
              const Divider(height: 24),

              // 스크롤 가능한 컨텐츠
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1.1 조사결과
                      const _HistorySectionTitle('1.1 조사결과'),
                      const SizedBox(height: 8),
                      _buildSurveyTable(),
                      const SizedBox(height: 24),

                      // 1.2 보존사항
                      const _HistorySectionTitle('1.2 보존사항'),
                      const SizedBox(height: 8),
                      _buildConservationTable(),
                      const SizedBox(height: 24),

                      // 1.3 관리사항
                      const _HistorySectionTitle('1.3 관리사항'),
                      const SizedBox(height: 8),
                      _buildManagementTable(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이력 데이터를 불러왔습니다')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurveyTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(3),
      },
      children: const [
        TableRow(
          decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [
            _HistoryTableCell('구분', isHeader: true),
            _HistoryTableCell('내용', isHeader: true),
          ],
        ),
        TableRow(children: [
          _HistoryTableCell('구조부'),
          _HistoryTableCell('이하 내용 1.1 총괄사항 참고'),
        ]),
        TableRow(children: [
          _HistoryTableCell('축석(벽체부)'),
          _HistoryTableCell('—'),
        ]),
        TableRow(children: [
          _HistoryTableCell('지붕부'),
          _HistoryTableCell('* 이하 내용 1.1 총괄사항 참고', isRed: true),
        ]),
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
      children: const [
        TableRow(
          decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [
            _HistoryTableCell('구분', isHeader: true),
            _HistoryTableCell('부재', isHeader: true),
            _HistoryTableCell('조사내용(현상)', isHeader: true),
            _HistoryTableCell('사진/위치', isHeader: true),
          ],
        ),
        TableRow(children: [
          _HistoryTableCell('구조부'),
          _HistoryTableCell('기단'),
          _HistoryTableCell('이하 내용 1.2 보존사항 참고'),
          _HistoryTableCell('7,710'),
        ]),
        TableRow(children: [
          _HistoryTableCell('지붕부'),
          _HistoryTableCell('—'),
          _HistoryTableCell('* 필요시 사진 보이기', isRed: true),
          _HistoryTableCell(''),
        ]),
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
      children: const [
        TableRow(
          decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
          children: [
            _HistoryTableCell('구분', isHeader: true),
            _HistoryTableCell('부재', isHeader: true),
            _HistoryTableCell('조사내용(현상)', isHeader: true),
            _HistoryTableCell('있음', isHeader: true),
            _HistoryTableCell('없음', isHeader: true),
          ],
        ),
        TableRow(children: [
          _HistoryTableCell('소방 및 안전관리'),
          _HistoryTableCell('방재/피뢰설비'),
          _HistoryTableCell('* 이하 내용 1.3 관리사항 참고', isRed: true),
          _HistoryTableCell('■'),
          _HistoryTableCell('□'),
        ]),
        TableRow(children: [
          _HistoryTableCell('전기시설'),
          _HistoryTableCell('전선/조명 등'),
          _HistoryTableCell('* 이하 내용 1.3 관리사항 참고', isRed: true),
          _HistoryTableCell('□'),
          _HistoryTableCell('■'),
        ]),
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isRed ? Colors.red : Colors.black87,
        ),
      ),
    );
  }
}
