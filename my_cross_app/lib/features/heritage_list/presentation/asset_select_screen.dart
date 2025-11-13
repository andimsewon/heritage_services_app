import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_cross_app/core/config/env.dart';
import 'package:my_cross_app/core/ui/widgets/ambient_background.dart';
import 'package:my_cross_app/core/services/firebase_service.dart';
import 'package:my_cross_app/core/ui/widgets/responsive_table.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/basic_info_screen.dart';
import 'package:my_cross_app/features/heritage_list/data/heritage_api.dart';

class AssetSelectScreen extends StatefulWidget {
  static const route = '/asset-select';
  const AssetSelectScreen({super.key});

  @override
  State<AssetSelectScreen> createState() => _AssetSelectScreenState();
}

class _AssetSelectScreenState extends State<AssetSelectScreen> {
  final _keyword = TextEditingController();
  late final HeritageApi _api = HeritageApi(Env.proxyBase);
  final _fb = FirebaseService();

  static const int _pageSize = 20;

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
    '21': '부산',
    '22': '대구',
    '23': '인천',
    '24': '광주',
    '25': '대전',
    '26': '울산',
    '31': '경기',
    '33': '충북',
    '34': '충남',
    '35': '전북',
    '36': '전남',
    '37': '경북',
    '38': '경남',
    '50': '제주',
  };

  final List<HeritageRow> _rows = [];
  final List<Map<String, dynamic>> _customRows = [];
  int _page = 1;
  int _totalCount = 0;
  bool _loading = false;
  String _curKeyword = '';
  bool _showCustomOnly = false;
  DateTime? _lastUpdated;

  // 상세 주소 캐싱 (성능 최적화)
  final Map<String, String> _detailAddressCache = {};

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  // 커스텀 문화재 클릭 시 상세 화면으로 이동
  void _openCustomHeritageDialog(Map<String, dynamic> m) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BasicInfoScreen(),
        settings: RouteSettings(
          arguments: {
            'isCustom': true,
            'customId': m['__docId'],
            'name': m['name'],
          },
        ),
      ),
    );
  }

  // API 문화재 클릭 시 상세 화면으로 이동
  void _openApiHeritageDialog(HeritageRow r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BasicInfoScreen(),
        settings: RouteSettings(
          arguments: {
            'isCustom': false,
            'ccbaKdcd': r.ccbaKdcd,
            'ccbaAsno': r.ccbaAsno,
            'ccbaCtcd': r.ccbaCtcd,
            'name': r.name,
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCustom(Map<String, dynamic> data) async {
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
      await _fb.deleteCustomHeritage(data['__docId'] as String);
      if (mounted) {
        _fetch(reset: true);
      }
    }
  }

  Future<void> _fetch({bool reset = false, int? page}) async {
    if (_loading) return;
    final targetPage = reset ? 1 : (page ?? _page);
    if (targetPage < 1) return;
    setState(() => _loading = true);

    if (reset) {
      _curKeyword = _keyword.text.trim();
    }

    try {
      final res = await _api.fetchList(
        keyword: _curKeyword.isEmpty ? null : _curKeyword,
        kind: (_kind == null || _kind!.isEmpty) ? null : _kind,
        region: (_region == null || _region!.isEmpty) ? null : _region,
        page: targetPage,
        size: _pageSize,
      );
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
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(res.items);
        _page = targetPage;
        _totalCount = res.totalCount;
        _customRows
          ..clear()
          ..addAll(filtered);
        _lastUpdated = DateTime.now();
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

  void _onSearch() => _fetch(reset: true);

  String _resolveCustomDetailAddress(
    Map<String, dynamic> data,
    String fallback,
  ) {
    // 수동으로 등록한 항목의 경우 상세 주소는 별도 필드에서만 가져옴
    // sojaeji는 소재지로만 사용되므로 상세 주소로 사용하지 않음
    final candidates = [
      data['ccbaLcad'],
      data['lcad'],
      data['ccbaLcto'],
      data['lcto'],
    ];

    for (final candidate in candidates) {
      final value = (candidate as String? ?? '').trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    // fallback이 비어있으면 빈 문자열 반환 (sojaeji를 상세 주소로 사용하지 않음)
    return fallback.isNotEmpty ? fallback : '';
  }

  // 상세 주소 가져오기 (캐싱 사용) - 기본 정보 화면과 동일한 로직
  Future<String> _getDetailAddress(HeritageRow row) async {
    final cacheKey = '${row.ccbaKdcd}_${row.ccbaAsno}_${row.ccbaCtcd}';

    // 캐시에 있으면 반환
    if (_detailAddressCache.containsKey(cacheKey)) {
      return _detailAddressCache[cacheKey]!;
    }

    Map<String, dynamic>? extractItem(Map<String, dynamic> payload) {
      dynamic candidate = payload['item'];
      if (candidate == null && payload['result'] is Map<String, dynamic>) {
        candidate = (payload['result'] as Map<String, dynamic>)['item'];
      }

      if (candidate is Map<String, dynamic>) return candidate;
      if (candidate is List) {
        for (final element in candidate) {
          if (element is Map<String, dynamic>) {
            return element;
          }
        }
      }
      return null;
    }

    try {
      // 상세 정보 가져오기
      final detail = await _api.fetchDetail(
        ccbaKdcd: row.ccbaKdcd,
        ccbaAsno: row.ccbaAsno,
        ccbaCtcd: row.ccbaCtcd,
      );

      // 소재지 정보 추출 - 기본 정보 화면과 동일한 로직
      // 정기조사 지침 기준: 소재지는 lcad 우선, 없으면 lcto
      final item = extractItem(detail);
      if (item != null) {
        final lcto = (item['ccbaLcto'] as String? ?? '').trim();
        final lcad = (item['ccbaLcad'] as String? ?? '').trim();

        // 기본 정보 화면과 동일: lcad 우선, 없으면 lcto
        final fullAddress = lcad.isNotEmpty ? lcad : lcto;

        // 캐시에 저장
        if (fullAddress.isNotEmpty) {
          _detailAddressCache[cacheKey] = fullAddress;
          return fullAddress;
        }
      }
    } catch (e) {
      debugPrint('상세 주소 가져오기 실패: $e');
    }

    // 실패 시 기본 주소 반환
    return row.sojaeji.isNotEmpty ? row.sojaeji : row.addr;
  }

  void _goToPage(int page) {
    final totalPages = _totalPages;
    if (page < 1 || page > totalPages || page == _page) return;
    _fetch(page: page);
  }

  int get _totalPages {
    if (_totalCount <= 0) return 0;
    return (_totalCount + _pageSize - 1) ~/ _pageSize;
  }

  String _formatCount(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buffer.write(s[i]);
      final remaining = s.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return '동기화 대기';
    final date = value;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute 업데이트';
  }

  Widget _buildFilterCard() {
    Widget buildDropdown({
      required String label,
      required String? value,
      required Map<String, String> options,
      required ValueChanged<String?> onChanged,
    }) {
      return DropdownButtonFormField<String>(
        value: value ?? '',
        items: options.entries
            .map(
              (e) =>
                  DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
            )
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      );
    }

    Widget buildSearchField({required bool dense}) {
      return TextFormField(
        controller: _keyword,
        textInputAction: TextInputAction.search,
        onFieldSubmitted: (_) => _onSearch(),
        decoration: InputDecoration(
          isDense: dense,
          labelText: '검색어',
          hintText: '유산명, 소재지 등',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            tooltip: '검색',
            onPressed: _onSearch,
            icon: const Icon(Icons.arrow_outward_rounded),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: buildDropdown(
                          label: '종목',
                          value: _kind,
                          options: _kindOptions,
                          onChanged: (v) => setState(() => _kind = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: buildDropdown(
                          label: '지역',
                          value: _region,
                          options: _regionOptions,
                          onChanged: (v) => setState(() => _region = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildSearchField(dense: true),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 200,
                  child: buildDropdown(
                    label: '종목',
                    value: _kind,
                    options: _kindOptions,
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 200,
                  child: buildDropdown(
                    label: '지역',
                    value: _region,
                    options: _regionOptions,
                    onChanged: (v) => setState(() => _region = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: buildSearchField(dense: false)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildShortcutChips(BuildContext context) {
    const shortcuts = <_ShortcutChipData>[
      _ShortcutChipData(icon: Icons.all_inclusive, label: '전체', kindCode: ''),
      _ShortcutChipData(
        icon: Icons.museum_outlined,
        label: '국보',
        kindCode: '11',
      ),
      _ShortcutChipData(
        icon: Icons.account_balance_outlined,
        label: '보물',
        kindCode: '12',
      ),
      _ShortcutChipData(icon: Icons.park_outlined, label: '사적', kindCode: '13'),
      _ShortcutChipData(
        icon: Icons.eco_outlined,
        label: '천연기념물',
        kindCode: '15',
      ),
    ];
    final currentKind = _kind ?? '';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final shortcut in shortcuts)
          _ShortcutChip(
            icon: shortcut.icon,
            label: shortcut.label,
            selected: currentKind == shortcut.kindCode,
            onSelected: () {
              setState(() {
                _kind = shortcut.kindCode;
              });
              _fetch(reset: true);
            },
          ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required bool isTableLayout,
  }) {
    final theme = Theme.of(context);
    final lastRefresh = _formatTimestamp(_lastUpdated);
    final customCount = _customRows.length;
    final totalPages = _totalPages;
    final pageLabel = totalPages == 0
        ? '0 / 0쪽'
        : '${_page.toString().padLeft(2, '0')} / ${totalPages.toString().padLeft(2, '0')}쪽';
    final badgeSpacing = isTableLayout ? 18.0 : 12.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 뱃지들을 한 줄로 배치
            _SummaryBadge(
              label: '총 검색 건수',
              value: _formatCount(_totalCount),
              icon: Icons.layers_outlined,
              color: const Color(0xFF1D4ED8),
            ),
            const SizedBox(width: 12),
            _SummaryBadge(
              label: '내가 추가한 유산',
              value: customCount.toString(),
              icon: Icons.edit_note_outlined,
              color: const Color(0xFFDB2777),
            ),
            const SizedBox(width: 12),
            _SummaryBadge(
              label: '현재 페이지',
              value: pageLabel,
              icon: Icons.menu_book_outlined,
              color: const Color(0xFF0F766E),
            ),
            const Spacer(),
            // 토글과 새로고침을 한 줄에
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch.adaptive(
                  value: _showCustomOnly,
                  onChanged: (value) =>
                      setState(() => _showCustomOnly = value),
                ),
                const SizedBox(width: 4),
                Text('내 추가만', style: theme.textTheme.bodySmall),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: '새로고침',
                  onPressed: _loading ? null : () => _fetch(reset: true),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const _CellHeader('종목', flex: 2),
          const _CellHeader('유산명', flex: 4),
          const _CellHeader('소재지', flex: 3),
          const Expanded(
            flex: 3,
            child: Text('주소', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          // 삭제 버튼 공간을 위한 고정 너비 (40px)
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildResultList({required bool tableLayout}) {
    final apiRows = _showCustomOnly ? const <HeritageRow>[] : _rows;
    final totalItems = _customRows.length + apiRows.length;
    if (totalItems == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 48),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.travel_explore_outlined, size: 32, color: Colors.grey),
              SizedBox(height: 12),
              Text('검색 결과가 없습니다'),
            ],
          ),
        ],
      );
    }

    final padding = tableLayout
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(vertical: 6);
    final separator = tableLayout
        ? const Divider(height: 0)
        : const SizedBox(height: 12);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: totalItems,
      separatorBuilder: (_, __) => separator,
      itemBuilder: (context, index) {
        if (index < _customRows.length) {
          final data = _customRows[index];
          // 수동으로 등록한 항목의 경우 sojaeji에 입력한 값 그대로를 소재지로 표시
          // sojaeji 필드를 직접 사용하여 사용자가 입력한 값 그대로 표시
          final sojaejiValue = (data['sojaeji'] as String? ?? '').trim();
          final addrValue = (data['addr'] as String? ?? '').trim();
          // 상세 주소는 별도 필드(lcto, lcad 등)에서만 가져오고, sojaeji는 절대 사용하지 않음
          final detailAddress = _resolveCustomDetailAddress(
            data,
            '', // fallback을 빈 문자열로 전달하여 sojaeji가 상세 주소로 사용되지 않도록 함
          );
          // 수동 등록 항목: sojaeji를 우선 사용 (입력한 값 그대로 표시)
          // sojaeji가 비어있을 때만 addr을 fallback으로 사용
          final region = sojaejiValue.isNotEmpty ? sojaejiValue : addrValue;

          if (tableLayout) {
            return _CustomRow(
              data: data,
              region: region,
              detailAddress: detailAddress,
              onTap: () => _openCustomHeritageDialog(data),
              onDelete: () => _confirmDeleteCustom(data),
            );
          }

          return _HeritageListCard(
            badge: data['kindName'] as String? ?? '',
            title: data['name'] as String? ?? '',
            location: region.isNotEmpty ? region : null,
            address: detailAddress,
            onTap: () => _openCustomHeritageDialog(data),
            onDelete: () => _confirmDeleteCustom(data),
            isCustom: true,
          );
        }

        final row = apiRows[index - _customRows.length];
        final addrText = row.addr.trim();
        final sojaejiText = row.sojaeji.trim();
        final region = addrText.isNotEmpty ? addrText : sojaejiText;
        final detailFallback = sojaejiText.isNotEmpty ? sojaejiText : addrText;
        if (tableLayout) {
          return InkWell(
            onTap: () => _openApiHeritageDialog(row),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _Cell(row.kindName, flex: 2),
                  _Cell(row.name, flex: 4),
                  _Cell(region, flex: 3),
                  Expanded(
                    flex: 3,
                    child: FutureBuilder<String>(
                      future: _getDetailAddress(row),
                      builder: (context, snapshot) {
                        final detail =
                            snapshot.hasData && snapshot.data!.trim().isNotEmpty
                            ? snapshot.data!.trim()
                            : detailFallback;
                        return Text(
                          detail.isNotEmpty ? detail : '주소 정보 없음',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  // 삭제 버튼이 없는 API 항목도 동일한 공간(40px) 확보하여 정렬 유지
                  const SizedBox(width: 40),
                ],
              ),
            ),
          );
        }

        return _HeritageListCard(
          badge: row.kindName,
          title: row.name,
          location: region,
          address: detailFallback,
          row: row,
          getDetailAddress: _getDetailAddress,
          onTap: () => _openApiHeritageDialog(row),
        );
      },
    );
  }

  Widget _buildPagination() {
    final totalPages = _totalPages;
    if (totalPages <= 1) return const SizedBox.shrink();

    final current = _page;
    final startPage = ((current - 1) ~/ 5) * 5 + 1;
    int endPage = startPage + 4;
    if (endPage > totalPages) endPage = totalPages;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          if (startPage > 1)
            _PaginationButton(
              label: '≪',
              onPressed: _loading ? null : () => _goToPage(1),
            ),
          if (current > 1)
            _PaginationButton(
              label: '이전',
              onPressed: _loading ? null : () => _goToPage(current - 1),
            ),
          for (int i = startPage; i <= endPage; i++)
            _PaginationButton(
              label: '$i',
              selected: i == current,
              onPressed: i == current || _loading ? null : () => _goToPage(i),
            ),
          if (current < totalPages)
            _PaginationButton(
              label: '다음',
              onPressed: _loading
                  ? null
                  : () => _goToPage(
                      endPage < totalPages ? endPage + 1 : totalPages,
                    ),
            ),
          if (endPage < totalPages)
            _PaginationButton(
              label: '≫',
              onPressed: _loading ? null : () => _goToPage(totalPages),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('국가 유산 검색'),
        actions: const [],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTableLayout = constraints.maxWidth >= 960;
                final horizontalPadding = constraints.maxWidth >= 1280
                    ? 48.0
                    : 16.0;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 16,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTableLayout ? 1200 : 720,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFilterCard(),
                          const SizedBox(height: 12),
                          _buildShortcutChips(context),
                          const SizedBox(height: 16),
                          _buildSummaryCard(
                            context,
                            isTableLayout: isTableLayout,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '총 ${_formatCount(_totalCount)}건',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _showCustomOnly
                                    ? const _InlineBadge(label: '내 추가만 보기')
                                    : const SizedBox.shrink(),
                              ),
                              const Spacer(),
                              Text(
                                _totalPages == 0
                                    ? '페이지 0 / 0'
                                    : '페이지 $_page / $_totalPages',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _loading
                                ? const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                  )
                                : const SizedBox(height: 2),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: isTableLayout
                                ? ResponsiveTable(
                                    minWidth: 960,
                                    child: Column(
                                      children: [
                                        _buildTableHeader(context),
                                        const Divider(height: 0),
                                        Expanded(
                                          child: RefreshIndicator(
                                            onRefresh: () =>
                                                _fetch(reset: true),
                                            child: _buildResultList(
                                              tableLayout: true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: () => _fetch(reset: true),
                                    child: _buildResultList(tableLayout: false),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          _buildPagination(),
                        ],
                      ),
                    ),
                  ),
                );
              },
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

class _SummaryBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutChipData {
  final IconData icon;
  final String label;
  final String kindCode;
  const _ShortcutChipData({
    required this.icon,
    required this.label,
    required this.kindCode,
  });
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: const Color(0xFF9A3412)) ??
            const TextStyle(
              color: Color(0xFF9A3412),
              fontWeight: FontWeight.w600,
            ),
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

// 상세 주소를 비동기로 가져와서 표시하는 셀
class _LocationCell extends StatefulWidget {
  final HeritageRow row;
  final Future<String> Function(HeritageRow) getDetailAddress;

  const _LocationCell({required this.row, required this.getDetailAddress});

  @override
  State<_LocationCell> createState() => _LocationCellState();
}

class _LocationCellState extends State<_LocationCell> {
  String? _cachedAddress;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 초기 주소 표시 (sojaeji 또는 addr)
    _cachedAddress = widget.row.sojaeji.isNotEmpty
        ? widget.row.sojaeji
        : widget.row.addr;

    // 배경에서 상세 주소 가져오기
    _loadDetailAddress();
  }

  Future<void> _loadDetailAddress() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final detailAddress = await widget.getDetailAddress(widget.row);
      if (mounted && detailAddress != _cachedAddress) {
        setState(() {
          _cachedAddress = detailAddress;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _cachedAddress ?? '',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.black, // 검정색으로 변경
      ),
    );
  }
}

class _HeritageListCard extends StatelessWidget {
  const _HeritageListCard({
    required this.badge,
    required this.title,
    this.location,
    this.row,
    this.getDetailAddress,
    required this.address,
    required this.onTap,
    this.onDelete,
    this.isCustom = false,
  });

  final String badge;
  final String title;
  final String? location; // 커스텀 항목용
  final HeritageRow? row; // API 항목용
  final Future<String> Function(HeritageRow)? getDetailAddress;
  final String address;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regionText = (location ?? '').trim();
    final detailFallback = address.trim();
    final labelStyle =
        (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        );
    final valueStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
          color: Colors.grey.shade700,
        );

    Widget buildInfoText({
      required String label,
      required String value,
      Color? valueColor,
    }) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label  ', style: labelStyle),
            TextSpan(
              text: value,
              style: valueStyle.copyWith(color: valueColor ?? valueStyle.color),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ChipLabel(
                    text: badge.isEmpty ? '미상' : badge,
                    backgroundColor: const Color(0xFFE4ECFF),
                    textColor: const Color(0xFF1D4ED8),
                  ),
                  if (isCustom) ...[
                    const SizedBox(width: 8),
                    const _ChipLabel(
                      text: '내 추가',
                      backgroundColor: Color(0xFFFFEDD5),
                      textColor: Color(0xFFC2410C),
                    ),
                  ],
                  const Spacer(),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '삭제',
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title.isEmpty ? '이름 미상' : title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              buildInfoText(
                label: '소재지',
                value: regionText.isNotEmpty ? regionText : '소재지 정보 없음',
                valueColor: regionText.isNotEmpty
                    ? Colors.grey.shade700
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 4),
              if (row != null && getDetailAddress != null)
                FutureBuilder<String>(
                  future: getDetailAddress!(row!),
                  builder: (context, snapshot) {
                    final detailValue =
                        snapshot.hasData && snapshot.data!.trim().isNotEmpty
                        ? snapshot.data!.trim()
                        : detailFallback;
                    final hasDetail = detailValue.isNotEmpty;
                    final waiting =
                        snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData;
                    final displayText = waiting
                        ? '주소 불러오는 중…'
                        : (hasDetail ? detailValue : '주소 정보 없음');
                    final valueColor = waiting
                        ? Colors.grey.shade500
                        : hasDetail
                        ? Colors.grey.shade800
                        : Colors.grey.shade400;
                    return buildInfoText(
                      label: '주소',
                      value: displayText,
                      valueColor: valueColor,
                    );
                  },
                )
              else
                buildInfoText(
                  label: '주소',
                  value: detailFallback.isNotEmpty
                      ? detailFallback
                      : '주소 정보 없음',
                  valueColor: detailFallback.isNotEmpty
                      ? Colors.grey.shade800
                      : Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _CustomRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String region;
  final String detailAddress;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CustomRow({
    required this.data,
    required this.region,
    required this.detailAddress,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 수동 등록 항목: sojaeji에 입력한 값 그대로를 소재지로 표시
    // region은 이미 sojaeji를 우선 사용하도록 설정되어 있지만,
    // 혹시 모를 경우를 대비해 sojaeji를 직접 확인
    final sojaejiValue = (data['sojaeji'] as String? ?? '').trim();
    final displayRegion = sojaejiValue.isNotEmpty
        ? sojaejiValue
        : (region.isNotEmpty ? region : '');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            _Cell('${data['kindName'] as String? ?? ''} (내 추가)', flex: 2),
            _Cell(data['name'] as String? ?? '', flex: 4),
            _Cell(displayRegion, flex: 3),
            // 주소 열: flex: 3으로 헤더와 일치
            Expanded(
              flex: 3,
              child: Text(
                detailAddress.isNotEmpty ? detailAddress : '주소 정보 없음',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black),
              ),
            ),
            // 삭제 버튼: 고정 너비 (40px)로 정렬 유지
            SizedBox(
              width: 40,
              child: IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  const _PaginationButton({
    required this.label,
    this.selected = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const selectedBg = Color(0xFF1F4E79);
    const defaultBorder = Color(0xFFDCDCDC);
    const hoverBg = Color(0xFFF2F6FB);
    const defaultTextColor = Color(0xFF333333);
    const disabledTextColor = Color(0xFF9CA3AF);

    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white;
        }
        if (selected) {
          return selectedBg;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return hoverBg;
        }
        return Colors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabledTextColor;
        }
        return selected ? Colors.white : defaultTextColor;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return hoverBg.withValues(alpha: 0.6);
        }
        if (states.contains(WidgetState.hovered)) {
          return hoverBg.withValues(alpha: 0.4);
        }
        return null;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: defaultBorder);
        }
        if (selected ||
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return const BorderSide(color: selectedBg);
        }
        return const BorderSide(color: defaultBorder);
      }),
    );

    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      child: TextButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: Text(label, style: textStyle, textAlign: TextAlign.center),
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        tooltip: '창 닫기',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          '국가유산 신규등록',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '필수 항목을 먼저 입력하고 필요 시 기본 개요 정보를 추가하세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '* 필수입력사항',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: '종목명 (예: 국보)',
                    controller: _kindName,
                    requiredField: true,
                  ),
                  _buildTextField(label: '종목코드 (예: 11)', controller: _kindCode),
                  _buildTextField(
                    label: '유산명',
                    controller: _name,
                    requiredField: true,
                  ),
                  _buildTextField(
                    label: '소재지',
                    controller: _sojaeji,
                    requiredField: true,
                  ),
                  _buildTextField(label: '주소', controller: _addr),
                  const SizedBox(height: 24),
                  const Text(
                    '기본 개요 (선택 입력)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(label: '지정(등록)일', controller: _asdt),
                  _buildTextField(label: '소유자', controller: _owner),
                  _buildTextField(label: '관리자', controller: _admin),
                  _buildTextField(label: '소재지', controller: _lcto),
                  _buildTextField(label: '소재지 상세', controller: _lcad),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('등록'),
                      ),
                      const SizedBox(width: 20),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool requiredField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (!requiredField) return null;
          if (value == null || value.trim().isEmpty) {
            return '필수 입력 항목입니다';
          }
          return null;
        },
      ),
    );
  }
}
