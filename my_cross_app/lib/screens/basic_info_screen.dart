import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/heritage_api.dart';
import '../env.dart';
import '../services/firebase_service.dart';
import '../services/image_acquire.dart';
import '../services/pick_and_upload.dart';


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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args == null) {
      _args = (ModalRoute.of(context)?.settings.arguments ?? {}) as Map<String, dynamic>;
      heritageId =
      "${_args?['ccbaKdcd']}_${_args?['ccbaAsno']}_${_args?['ccbaCtcd']}";
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.fetchDetail(
        ccbaKdcd: _args?['ccbaKdcd'] ?? '',
        ccbaAsno: _args?['ccbaAsno'] ?? '',
        ccbaCtcd: _args?['ccbaCtcd'] ?? '',
      );
      setState(() => _detail = d);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('상세 로드 실패: $e')));
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

  // ───────────────────────── 문화유산 현황 사진 업로드
  Future<void> _addPhoto() async {
    final pair = await ImageAcquire.pick(context);
    if (pair == null) return;
    final (bytes, sizeGetter) = pair;

    final title = await _askTitle(context);
    if (title == null) return;

    await _fb.addPhoto(
      heritageId: heritageId,
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
            decoration: const InputDecoration(hintText: '예: 남측면 전경')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('등록')),
        ],
      ),
    );
  }

  // ───────────────────────── 손상부 조사 촬영→AI 분석→저장
  Future<void> _startDamageSurvey() async {
    final pair = await ImageAcquire.pick(context);
    if (pair == null) return;
    final (bytes, sizeGetter) = pair;

    // 원본 사진 업로드
    await _fb.addPhoto(
      heritageId: heritageId,
      title: '손상부 조사 원본',
      imageBytes: bytes,
      sizeGetter: sizeGetter,
      folder: 'damage_surveys',
    );

    // 최신 업로드 URL 가져오기
    final latest = await FirebaseFirestore.instance
        .collection('heritages')
        .doc(heritageId)
        .collection('damage_surveys')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    final imageUrl = (latest.docs.first.data())['url'] as String;

    // AI 분석 (더미, 나중에 FastAPI 교체)
    final detections = await _callDamageAI(bytes);

    // Firestore에 손상부 조사 문서 저장
    await _fb.addDamageSurvey(
      heritageId: heritageId,
      imageUrl: imageUrl,
      detections: detections,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('손상부 조사 등록 완료')));
    }
  }

  Future<List<Map<String, dynamic>>> _callDamageAI(Uint8List bytes) async {
    // ⚠️ 더미 응답 (향후 FastAPI로 교체)
    return [
      {
        'label': '갈라짐',
        'score': 0.88,
        'x': 0.35,
        'y': 0.25,
        'w': 0.20,
        'h': 0.15
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final kind = _read([['result', 'item', 'ccmaName'], ['item', 'ccmaName']]);
    final asdt = _read([['result', 'item', 'ccbaAsdt'], ['item', 'ccbaAsdt']]);
    final owner = _read([['result', 'item', 'ccbaPoss'], ['item', 'ccbaPoss']]);
    final admin = _read([['result', 'item', 'ccbaAdmin'], ['item', 'ccbaAdmin']]);
    final lcto = _read([['result', 'item', 'ccbaLcto'], ['item', 'ccbaLcto']]);
    final lcad = _read([['result', 'item', 'ccbaLcad'], ['item', 'ccbaLcad']]);

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('기본개요')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '국가유산명: ${_name.isEmpty ? '미상' : _name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _InfoRow('종목', kind),
          _InfoRow('지정(등록)일', asdt),
          _InfoRow('소유자', owner),
          _InfoRow('관리자', admin),
          _InfoRow('소재지', lcto),
          if (lcad.isNotEmpty) _InfoRow('소재지 상세', lcad),

          const Divider(height: 32),

          // ───── 문화유산 현황(사진)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('문화유산 현황',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _addPhoto,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('사진 등록'),
                )
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
                      '${d['width'] ?? '?'}x${d['height'] ?? '?'}',
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
                const Text('손상부 조사',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
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
            height: 220,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _fb.damageStream(heritageId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('등록된 손상부 조사가 없습니다'));
                }
                final d = docs.first.data();
                final url = d['imageUrl'] as String? ?? '';
                final dets =
                (d['detections'] as List? ?? []).cast<Map<String, dynamic>>();
                return _DamagePreview(url: url, detections: dets);
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
  const _InfoRow(this.label, String? value, {super.key})
      : value = value ?? '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
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
  const _PhotoCard(
      {required this.title, required this.url, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image))),
              )),
          const SizedBox(height: 6),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
    return LayoutBuilder(builder: (context, box) {
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
                  border: Border.all(width: 2, color: Colors.red),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withOpacity(0.8),
                    child: Text(
                        '${m['label']} ${(m['score'] as num).toStringAsFixed(2)}'),
                  ),
                ),
              ),
            );
          })
        ],
      );
    });
  }
}
