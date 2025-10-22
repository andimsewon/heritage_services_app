import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert' show base64Decode; // base64Decode 사용 대비
import 'dart:async';                     // Timer(debounce) 대비

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
    await _openDamageDetectionDialog(autoCapture: true);
  }

  Future<void> _openDamageDetectionDialog({bool autoCapture = false}) async {
    if (!mounted) return;
    final result = await showDialog<DamageDetectionResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DamageDetectionDialog(
        aiService: _ai,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('손상부 조사 등록 완료')),
      );
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
                  onPressed: () => _openDamageDetectionDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('조사등록'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 8),
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
                  icon: const Icon(Icons.assignment),
                  label: const Text('심화조사'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade600,
                  ),
                ),
                const SizedBox(width: 8),
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
          Icon(Icons.image_not_supported, 
               size: 32, 
               color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text(
            '이미지 로딩 실패',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'URL 확인 필요',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

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
              child: _isValidUrl(url) 
                ? Image.network(
                    _getProxiedUrl(url),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('이미지 로딩 에러: $error');
                      print('원본 URL: $url');
                      print('프록시 URL: ${_getProxiedUrl(url)}');
                      return _buildErrorWidget();
                    },
                  )
                : _buildErrorWidget(),
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
            Image.network(_getProxiedUrl(url), fit: BoxFit.contain),
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
  final List<_HistoryImage> _locationImages = [];
  final List<_HistoryImage> _currentPhotos = [];
  final List<_HistoryImage> _damagePhotos = [];

  Future<void> _addPhoto(List<_HistoryImage> target) async {
    final picked = await ImageAcquire.pick(context);
    if (picked == null) return;
    final (bytes, _) = picked;
    if (!mounted) return;
    setState(() => target.add(_HistoryImage.memory(bytes)));
  }

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
                      const SizedBox(height: 24),

                      // 1.4 위치현황
                      const _HistorySectionTitle('1.4 위치현황'),
                      const SizedBox(height: 8),
                      _buildHistoryPhotoSection(
                        title: '위치 도면/위성자료 등록',
                        description: '위치 및 도면 자료를 업로드하세요.',
                        photos: _locationImages,
                        onAdd: () => _addPhoto(_locationImages),
                      ),
                      const SizedBox(height: 24),

                      // 1.5 현황사진
                      const _HistorySectionTitle('1.5 현황사진'),
                      const SizedBox(height: 8),
                      _buildHistoryPhotoSection(
                        title: '현황 사진 등록',
                        description: '최근 촬영한 현황 사진을 관리합니다.',
                        photos: _currentPhotos,
                        onAdd: () => _addPhoto(_currentPhotos),
                      ),
                      const SizedBox(height: 24),

                      // 1.6 손상부 조사
                      const _HistorySectionTitle('1.6 손상부 조사'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '* 직전 조사 대비 손상부 변화를 비교하세요.',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildHistoryPhotoSection(
                        title: '손상부 사진 등록',
                        description: '손상부 조사 결과를 사진과 함께 보관합니다.',
                        photos: _damagePhotos,
                        onAdd: () => _addPhoto(_damagePhotos),
                      ),
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
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
            child: InkWell(
              onTap: () => _showPreview(context),
            ),
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
            child: Image(
              image: image.provider,
              fit: BoxFit.contain,
            ),
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
      bytes != null ? MemoryImage(bytes!) : NetworkImage(url!);
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
— DamageDetectionDialog - AI 손상부 조사 다이얼로그
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
        (a, b) => ((b['score'] as num?) ?? 0)
            .compareTo(((a['score'] as num?) ?? 0)),
      );
    final normalized = _normalizeDetections(sorted);

    setState(() {
      _loading = false;
      _detections = normalized;
      if (_detections.isNotEmpty) {
        _selectedLabel = _detections.first['label'] as String?;
        _selectedConfidence =
            (_detections.first['score'] as num?)?.toDouble();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 먼저 촬영하거나 업로드하세요.')),
      );
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
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '손상부 조사',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: _loading ? null : _pickImageAndDetect,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('사진 촬영 또는 업로드'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 44),
                  ),
                ),
                const SizedBox(height: 16),

                _buildPreview(),
                const SizedBox(height: 20),

                if (_imageBytes != null) _buildAiSection(),
                const SizedBox(height: 24),

                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  '조사 정보 입력',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _infoField('손상 위치', _locationController, hint: '예: 남향 2번 평주'),
                _infoField('손상 부위', _partController, hint: '예: 기둥 - 상부'),
                Row(
                  children: [
                    Expanded(
                      child: _infoField('온도(℃)', _temperatureController,
                          hint: '예: 23'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                          _infoField('습도(%)', _humidityController, hint: '예: 55'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _severityGrade,
                  decoration: const InputDecoration(
                    labelText: '심각도 (A~F)',
                    border: OutlineInputBorder(),
                  ),
                  items: const ['A', 'B', 'C', 'D', 'E', 'F']
                      .map(
                        (g) => DropdownMenuItem(value: g, child: Text(g)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _severityGrade = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _opinionController,
                  decoration: const InputDecoration(
                    labelText: '조사자 의견',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _loading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 44),
                      ),
                      child: const Text('저장'),
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
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
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
                (label) => DropdownMenuItem(
                  value: label,
                  child: Text(label),
                ),
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
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              explanation,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
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

    double clamp01(double value) =>
        value.clamp(0.0, 1.0).toDouble();

    return detections.map((det) {
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
    }).toList(growable: false);
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
      if (selectedConfidence != null)
        'selectedConfidence': selectedConfidence,
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
                              child: Image.network(
                                damageImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
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
