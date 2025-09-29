import 'package:flutter/material.dart';
import '../data/heritage_api.dart';
import '../services/firebase_service.dart';
import '../env.dart';
import 'basic_info_screen.dart';

class AssetSelectScreen extends StatefulWidget {
  static const route = '/asset-select';
  const AssetSelectScreen({super.key});

  @override
  State<AssetSelectScreen> createState() => _AssetSelectScreenState();
}

class _AssetSelectScreenState extends State<AssetSelectScreen> {
  final _keyword = TextEditingController();
  final _scroll = ScrollController();
  late final HeritageApi _api = HeritageApi(Env.proxyBase);
  final _fb = FirebaseService();

  // 필터 값 (샘플 코드표 — 실제는 서버/상수로 치환 가능)
  String? _kind = '';
  String? _region = '';

  final _kindOptions = const <String, String>{
    '': '종목전체',
    '11': '국보',
    '12': '보물',
    '13': '사적',
    '15': '천연기념물',
  };
  final _regionOptions = const <String, String>{
    '': '지역전체',
    '11': '서울',
    '24': '전북',
    '34': '충남',
    '48': '경남',
  };

  final List<HeritageRow> _rows = [];
  final List<Map<String, dynamic>> _customRows = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String _curKeyword = '';

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    if (reset) {
      _page = 1;
      _rows.clear();
      _customRows.clear();
      _hasMore = true;
      _curKeyword = _keyword.text.trim();
    }

    try {
      final res = await _api.fetchList(
        keyword: _curKeyword.isEmpty ? null : _curKeyword,
        kind: (_kind == null || _kind!.isEmpty) ? null : _kind,
        region: (_region == null || _region!.isEmpty) ? null : _region,
        page: _page,
        size: 20,
      );
      setState(() {
        _rows.addAll(res.items);
        _page += 1;
        _hasMore = _rows.length < res.totalCount;
      });
      // 커스텀 유산도 로드/필터링
      final snap = await _fb.customHeritagesStream().first;
      final all = snap.docs.map((e) => e.data()..['__docId'] = e.id).toList();
      final filtered = all.where((m) {
        final kw = _curKeyword.toLowerCase();
        final matchKw =
            kw.isEmpty ||
            (m['name'] as String? ?? '').toLowerCase().contains(kw) ||
            (m['sojaeji'] as String? ?? '').toLowerCase().contains(kw) ||
            (m['addr'] as String? ?? '').toLowerCase().contains(kw);
        final matchKind =
            (_kind == null || _kind!.isEmpty) ||
            (m['kindCode'] as String? ?? '') == _kind;
        // 지역 코드는 커스텀에는 별도 코드가 없으므로 주소 텍스트로 대략 필터
        final matchRegion =
            (_region == null || _region!.isEmpty) ||
            (m['addr'] as String? ?? '').contains(_region!);
        return matchKw && matchKind && matchRegion;
      }).toList();
      setState(() {
        _customRows
          ..clear()
          ..addAll(filtered);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('검색 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_hasMore &&
        !_loading &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _fetch();
    }
  }

  void _onSearch() => _fetch(reset: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('국가 유산 검색')),
      body: Column(
        children: [
          // ── 필터 바: 종목/지역/조건
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _kind ?? '',
                  items: _kindOptions.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _kind = v),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _region ?? '',
                  items: _regionOptions.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _region = v),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _keyword,
                    decoration: const InputDecoration(
                      labelText: '조건(유산명 등)',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('검색'),
                ),
              ],
            ),
          ),
          const Divider(height: 0),

          // 헤더
          Container(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Row(
              children: [
                _CellHeader('종목', flex: 2),
                _CellHeader('유산명', flex: 4),
                _CellHeader('소재지', flex: 3),
                _CellHeader('주소', flex: 3),
              ],
            ),
          ),

          // 표 리스트
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetch(reset: true),
              child: ListView.separated(
                controller: _scroll,
                itemCount: _customRows.length + _rows.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  if (i == _customRows.length + _rows.length) {
                    if (_loading) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_customRows.isEmpty && _rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('데이터가 없습니다')),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  // 커스텀 먼저, 그 다음 API 항목
                  if (i < _customRows.length) {
                    final m = _customRows[i];
                    return _CustomRow(
                      data: m,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          BasicInfoScreen.route,
                          arguments: {
                            'isCustom': true,
                            'customId': m['__docId'],
                            'name': m['name'],
                            'ccbaKdcd': m['kindCode'] ?? '',
                            'ccbaAsno': 'CUSTOM',
                            'ccbaCtcd': 'CUSTOM',
                          },
                        );
                      },
                      onDelete: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('삭제 확인'),
                            content: const Text('해당 국가 유산을 삭제하시겠습니까?'),
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
                        if (ok == true) {
                          await _fb.deleteCustomHeritage(
                            m['__docId'] as String,
                          );
                          _fetch(reset: true);
                        }
                      },
                    );
                  }

                  final r = _rows[i - _customRows.length];
                  return InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        BasicInfoScreen.route,
                        arguments: {
                          'id': r.id,
                          'name': r.name,
                          'region': r.addr,
                          'code': r.kindCode,
                          'ccbaKdcd': r.ccbaKdcd,
                          'ccbaAsno': r.ccbaAsno,
                          'ccbaCtcd': r.ccbaCtcd,
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _Cell(r.kindName, flex: 2),
                          _Cell(r.name, flex: 4),
                          _Cell(r.sojaeji, flex: 3),
                          _Cell(r.addr, flex: 3),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showDialog<Map<String, String>>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const _CreateCustomDialog(),
          );
          if (created != null) {
            await _fb.addCustomHeritage(
              kindCode: created['kindCode'] ?? '',
              kindName: created['kindName'] ?? '',
              name: created['name'] ?? '',
              sojaeji: created['sojaeji'] ?? '',
              addr: created['addr'] ?? '',
              asdt: created['asdt'],
              owner: created['owner'],
              admin: created['admin'],
              lcto: created['lcto'],
              lcad: created['lcad'],
            );
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('국가 유산이 추가되었습니다.')));
              _fetch(reset: true);
            }
          }
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CellHeader extends StatelessWidget {
  final String text;
  final int flex;
  const _CellHeader(this.text, {this.flex = 1});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  const _Cell(this.text, {this.flex = 1});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _CustomRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CustomRow({
    required this.data,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _Cell('${data['kindName'] as String? ?? ''} (내 추가)', flex: 2),
            _Cell(data['name'] as String? ?? '', flex: 4),
            _Cell(data['sojaeji'] as String? ?? '', flex: 3),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      data['addr'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
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

class _CreateCustomDialog extends StatefulWidget {
  const _CreateCustomDialog();
  @override
  State<_CreateCustomDialog> createState() => _CreateCustomDialogState();
}

class _CreateCustomDialogState extends State<_CreateCustomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kindName = TextEditingController();
  final _kindCode = TextEditingController();
  final _name = TextEditingController();
  final _sojaeji = TextEditingController();
  final _addr = TextEditingController();
  final _asdt = TextEditingController();
  final _owner = TextEditingController();
  final _admin = TextEditingController();
  final _lcto = TextEditingController();
  final _lcad = TextEditingController();

  @override
  void dispose() {
    _kindName.dispose();
    _kindCode.dispose();
    _name.dispose();
    _sojaeji.dispose();
    _addr.dispose();
    _asdt.dispose();
    _owner.dispose();
    _admin.dispose();
    _lcto.dispose();
    _lcad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('국가 유산 직접 추가'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _kindName,
                decoration: const InputDecoration(labelText: '종목명 (예: 국보)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '필수 입력' : null,
              ),
              TextFormField(
                controller: _kindCode,
                decoration: const InputDecoration(labelText: '종목코드 (예: 11)'),
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: '유산명'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '필수 입력' : null,
              ),
              TextFormField(
                controller: _sojaeji,
                decoration: const InputDecoration(labelText: '소재지'),
              ),
              TextFormField(
                controller: _addr,
                decoration: const InputDecoration(labelText: '주소'),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '기본 개요 (선택 입력)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextFormField(
                controller: _asdt,
                decoration: const InputDecoration(labelText: '지정(등록)일'),
              ),
              TextFormField(
                controller: _owner,
                decoration: const InputDecoration(labelText: '소유자'),
              ),
              TextFormField(
                controller: _admin,
                decoration: const InputDecoration(labelText: '관리자'),
              ),
              TextFormField(
                controller: _lcto,
                decoration: const InputDecoration(labelText: '소재지'),
              ),
              TextFormField(
                controller: _lcad,
                decoration: const InputDecoration(labelText: '소재지 상세'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop<Map<String, String>>(context, {
              'kindName': _kindName.text.trim(),
              'kindCode': _kindCode.text.trim(),
              'name': _name.text.trim(),
              'sojaeji': _sojaeji.text.trim(),
              'addr': _addr.text.trim(),
              'asdt': _asdt.text.trim(),
              'owner': _owner.text.trim(),
              'admin': _admin.text.trim(),
              'lcto': _lcto.text.trim(),
              'lcad': _lcad.text.trim(),
            });
          },
          child: const Text('추가'),
        ),
      ],
    );
  }
}
