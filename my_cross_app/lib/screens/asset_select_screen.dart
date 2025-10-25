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
  int _totalCount = 0;
  int get _totalPages => (_totalCount / 20).ceil();

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    // Pagination으로 변경하여 infinite scroll 비활성화
    // _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    // _scroll.removeListener(_onScroll);
    _scroll.dispose();
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
        _totalCount = res.totalCount;
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

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _page - 1) return;
    setState(() {
      _page = page;
      _rows.clear();
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 설정
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 12.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('국가 유산 검색'),
        actions: const [],
      ),
      body: Column(
        children: [
          // ── 필터 바: 종목/지역/조건
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                SizedBox(
                  width: isMobile ? screenWidth - (horizontalPadding * 2) : 300,
                  child: TextField(
                    controller: _keyword,
                    decoration: const InputDecoration(
                      labelText: '조건(유산명 등)',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _onSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('검색'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
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
                      onTap: () => _openCustomHeritageDialog(m),
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
                    onTap: () => _openApiHeritageDialog(r),
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

          // 페이지네이션 버튼
          if (_totalPages > 1) _buildPagination(isMobile),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
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
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildPagination(bool isMobile) {
    final currentPage = _page - 1; // _page is already incremented after fetch
    final start = ((currentPage - 1) ~/ 5) * 5 + 1;
    final end = (start + 4).clamp(1, _totalPages);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 이전 버튼
            _PaginationButton(
              label: isMobile ? '←' : '이전',
              isActive: false,
              onPressed: currentPage > 1 ? () => _goToPage(currentPage - 1) : null,
            ),

            // 페이지 번호 버튼
            ...List.generate(end - start + 1, (i) {
              final pageNum = start + i;
              return _PaginationButton(
                label: '$pageNum',
                isActive: pageNum == currentPage,
                onPressed: () => _goToPage(pageNum),
              );
            }),

            // 다음 버튼
            _PaginationButton(
              label: isMobile ? '→' : '다음',
              isActive: false,
              onPressed: currentPage < _totalPages ? () => _goToPage(currentPage + 1) : null,
            ),
            // 마지막 페이지 버튼
            if (!isMobile)
              _PaginationButton(
                label: '≫',
                isActive: false,
                onPressed: currentPage < _totalPages ? () => _goToPage(_totalPages) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

  const _PaginationButton({
    required this.label,
    required this.isActive,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? Colors.blue.shade50 : Colors.white,
        foregroundColor: isActive ? Colors.blue : Colors.grey.shade700,
        side: BorderSide(
          color: isActive ? Colors.blue : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(40, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
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
                  _buildTextField(
                    label: '종목코드 (예: 11)',
                    controller: _kindCode,
                  ),
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
                  _buildTextField(
                    label: '주소',
                    controller: _addr,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '기본 개요 (선택 입력)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: '지정(등록)일',
                    controller: _asdt,
                  ),
                  _buildTextField(
                    label: '소유자',
                    controller: _owner,
                  ),
                  _buildTextField(
                    label: '관리자',
                    controller: _admin,
                  ),
                  _buildTextField(
                    label: '소재지',
                    controller: _lcto,
                  ),
                  _buildTextField(
                    label: '소재지 상세',
                    controller: _lcad,
                  ),
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
                          backgroundColor: Theme.of(context).colorScheme.primary,
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
        decoration: InputDecoration(
          labelText: label,
        ),
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
