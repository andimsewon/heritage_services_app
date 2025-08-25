// lib/screens/asset_select_screen.dart (③ 국유재 선택 화면 - API 연동/페이징 완전본)
//
// - 검색(엔터/버튼) → 서버 프록시(Env.proxyBase) 호출
// - 무한 스크롤 페이징, 당겨서 새로고침
// - 항목 선택 시 ④ BasicInfoScreen 으로 전달

import 'package:flutter/material.dart';
import '../ui/widgets/yellow_nav_button.dart';
import 'basic_info_screen.dart';
import '../data/heritage_api.dart';
import '../env.dart';

class AssetSelectScreen extends StatefulWidget {
  static const route = '/asset-select';
  const AssetSelectScreen({super.key});

  @override
  State<AssetSelectScreen> createState() => _AssetSelectScreenState();
}

class _AssetSelectScreenState extends State<AssetSelectScreen> {
  final _q = TextEditingController();
  final _scroll = ScrollController();

  // 프록시 서버 기준 API 클라이언트
  late final HeritageApi _api = HeritageApi(Env.proxyBase);

  // 상태
  final List<HeritageItem> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String _currentQuery = '';

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
    _q.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    if (reset) {
      _page = 1;
      _hasMore = true;
      _items.clear();
      _currentQuery = _q.text.trim();
    }

    try {
      final res = await _api.fetchList(
        query: _currentQuery,
        page: _page,
        size: 20,
      );

      setState(() {
        _items.addAll(res.items);
        _page += 1;
        _hasMore = _items.length < res.totalCount;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('목록 로드 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _fetch(); // 다음 페이지
    }
  }

  void _onSearch() => _fetch(reset: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('국유재 선택')),
      body: Column(
        children: [
          // 검색 영역
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    decoration: const InputDecoration(
                      labelText: '검색(명칭/코드/지역)',
                      prefixIcon: Icon(Icons.search),
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

          // 리스트
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetch(reset: true),
              child: ListView.separated(
                controller: _scroll,
                itemCount: _items.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  // 로딩/빈 목록 표시용 마지막 셀
                  if (i == _items.length) {
                    if (_loading) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('데이터가 없습니다')),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  final it = _items[i];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(it.name),
                    subtitle: Text('${it.code} · ${it.region}'),
                    trailing: YellowNavButton(
                      label: '선택',
                      onTap: () => Navigator.pushNamed(
                        context,
                        BasicInfoScreen.route,
                        arguments: {
                          'name': it.name,
                          'region': it.region,
                          'code': it.code,
                          'id': it.id,
                          // 상세 조회용 3요소 같이 전달
                          'ccbaKdcd': it.ccbaKdcd,
                          'ccbaAsno': it.ccbaAsno,
                          'ccbaCtcd': it.ccbaCtcd,
                        },
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
