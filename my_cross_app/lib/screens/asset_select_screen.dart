import 'package:flutter/material.dart';
import '../data/heritage_api.dart';
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

  // 필터 값 (샘플 코드표 — 실제는 서버/상수로 치환 가능)
  String? _kind = '';
  String? _region = '';

  final _kindOptions = const <String, String>{
    '': '종목전체', '11': '국보', '12': '보물', '13': '사적', '15': '천연기념물',
  };
  final _regionOptions = const <String, String>{
    '': '지역전체', '11': '서울', '24': '전북', '34': '충남', '48': '경남',
  };

  final List<HeritageRow> _rows = [];
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('검색 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_hasMore && !_loading &&
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
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _kind = v),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _region ?? '',
                  items: _regionOptions.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
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
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
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
                itemCount: _rows.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  if (i == _rows.length) {
                    if (_loading) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('데이터가 없습니다')),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  final r = _rows[i];
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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