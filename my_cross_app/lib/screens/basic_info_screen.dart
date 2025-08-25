import 'package:flutter/material.dart';
import '../data/heritage_api.dart';
import '../env.dart';

/// ④ 기본개요 화면
/// - ③에서 넘어온 ccbaKdcd/ccbaAsno/ccbaCtcd로 상세 조회
/// - 문화유산청 상세 응답을 방어적으로 파싱하여 섹션별로 표시
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
  late final HeritageApi _api = HeritageApi(Env.proxyBase);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args == null) {
      _args = (ModalRoute.of(context)?.settings.arguments ?? {}) as Map<String, dynamic>;
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

  // ─────────────────────────────────────────────────────
  // XML→JSON 루트가 호출 시점마다 조금 달라서 방어적으로 값 읽기
  // 우선경로 → 대체경로 순으로 시도
  // ─────────────────────────────────────────────────────
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

  // 편의 단축키
  String get _name => _read([
    ['result', 'item', 'ccbaMnm1'],
    ['item', 'ccbaMnm1'],
  ]);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ── 주요 필드 매핑 (문화유산청 공식 문서 키 기준)
    final kind = _read([
      ['result', 'item', 'ccmaName'],
      ['item', 'ccmaName'],
    ]); // 종목 (예: 국보)

    final kind1 = _read([
      ['result', 'item', 'gcodeName'],
      ['item', 'gcodeName'],
    ]); // 분류1
    final kind2 = _read([
      ['result', 'item', 'bcodeName'],
      ['item', 'bcodeName'],
    ]);
    final kind3 = _read([
      ['result', 'item', 'mcodeName'],
      ['item', 'mcodeName'],
    ]);
    final kind4 = _read([
      ['result', 'item', 'scodeName'],
      ['item', 'scodeName'],
    ]);

    final qty = _read([
      ['result', 'item', 'ccbaQuan'],
      ['item', 'ccbaQuan'],
    ]); // 수량

    final asdt = _read([
      ['result', 'item', 'ccbaAsdt'],
      ['item', 'ccbaAsdt'],
    ]); // 지정(등록)일

    final owner = _read([
      ['result', 'item', 'ccbaPoss'],
      ['item', 'ccbaPoss'],
      ['result', 'item', 'owner'],
      ['item', 'owner'],
    ]); // 소유자

    final admin = _read([
      ['result', 'item', 'ccbaAdmin'],
      ['item', 'ccbaAdmin'],
      ['result', 'item', 'manage'],
      ['item', 'manage'],
    ]); // 관리자

    final era = _read([
      ['result', 'item', 'ccceName'],
      ['item', 'ccceName'],
    ]); // 시대

    final lcto = _read([
      ['result', 'item', 'ccbaLcto'],
      ['item', 'ccbaLcto'],
    ]); // 소재지(주소 요약)
    final lcad = _read([
      ['result', 'item', 'ccbaLcad'],
      ['item', 'ccbaLcad'],
    ]); // 소재지 상세

    final cpno = _read([
      ['result', 'item', 'ccbaCpno'],
      ['item', 'ccbaCpno'],
    ]); // 국가유산연계번호

    final kdcd = _read([
      ['result', 'item', 'ccbaKdcd'],
      ['item', 'ccbaKdcd'],
    ]);
    final asno = _read([
      ['result', 'item', 'ccbaAsno'],
      ['item', 'ccbaAsno'],
    ]);
    final ctcd = _read([
      ['result', 'item', 'ccbaCtcd'],
      ['item', 'ccbaCtcd'],
    ]);

    final lat = _read([
      ['result', 'item', 'latitude'],
      ['item', 'latitude'],
    ]);
    final lon = _read([
      ['result', 'item', 'longitude'],
      ['item', 'longitude'],
    ]);

    final regDt = _read([
      ['result', 'item', 'regDt'],
      ['item', 'regDt'],
    ]); // 최종수정일시(있을 때)

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('기본개요')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 제목
          Text(
            '국가유산명: ${_name.isEmpty ? '미상' : _name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ── 핵심 정보 블록 (스케치 요구안: 국가유산명/지정/지정일/소유자/관리자/소재지)
          _InfoRow('종목', kind),
          _InfoRow('지정(등록)일', asdt),
          _InfoRow('소유자', owner),
          _InfoRow('관리자', admin),
          _InfoRow('소재지', lcto),
          if (lcad.isNotEmpty) _InfoRow('소재지 상세', lcad),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // ── 분류/수량/시대 등 추가 메타
          const Text('분류 정보', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _InfoRow('분류1', kind1),
          _InfoRow('분류2', kind2),
          _InfoRow('분류3', kind3),
          _InfoRow('분류4', kind4),
          _InfoRow('수량', qty),
          _InfoRow('시대', era),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // ── 식별자/좌표
          const Text('식별자/좌표', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _InfoRow('연계번호', cpno),
          _InfoRow('키(종목/관리/시도)', [kdcd, asno, ctcd].where((e) => e.isNotEmpty).join(' / ')),
          _InfoRow('위치(위도/경도)', (lat.isNotEmpty || lon.isNotEmpty) ? '$lat / $lon' : ''),
          if (regDt.isNotEmpty) _InfoRow('최종수정일시', regDt),

          const SizedBox(height: 24),
          const Divider(),

          // ── 보존관리 이력 (후속)
          const Text('보존관리 이력 (후속 단계 연동 예정)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('※ 차기 단계에서 내부 DB/엑셀/포털 추가 API로 연동'),
          ),

          const SizedBox(height: 24),
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
