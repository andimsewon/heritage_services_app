import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../env.dart';
import '../../services/survey_repository.dart';
import '../../widgets/year_history_sheet.dart';
import 'detail_sections_strings_ko.dart';
import 'section11_investigation.dart';
import 'section12_conservation.dart';
import 'section13_management.dart';

class HeritageSurveySections extends StatefulWidget {
  const HeritageSurveySections({
    super.key,
    required this.heritageId,
    required this.heritageName,
    this.onNavigateList,
  });

  final String heritageId;
  final String heritageName;
  final VoidCallback? onNavigateList;

  @override
  State<HeritageSurveySections> createState() => _HeritageSurveySectionsState();
}

class _HeritageSurveySectionsState extends State<HeritageSurveySections> {
  final SurveyRepository _repository = SurveyRepository();
  late final String _currentYear = DateTime.now().year.toString();
  String _activeYear = DateTime.now().year.toString();
  SurveyModel? _model;
  bool _loading = true;
  bool _saving = false;
  bool _importing = false;
  bool _editing = false;
  bool _hasChanges = false;
  bool _adminOverrideGate = false;
  List<SurveyYearEntry> _years = const [];

  bool get _isCurrentYear => _activeYear == _currentYear;
  bool get _allowOverride => Env.adminOverrideEnabled;
  bool get _canEdit => _editing && (_isCurrentYear || _adminOverrideGate);
  bool get _canSave => _canEdit && _hasChanges && !_saving;
  bool get _importEnabled =>
      _isCurrentYear && !_importing && _years.any((y) => y.year != _currentYear);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? year}) async {
    final targetYear = year ?? _activeYear;
    setState(() {
      _loading = true;
      _activeYear = targetYear;
      _editing = false;
      _hasChanges = false;
      _adminOverrideGate = false;
    });
    try {
      final result = await Future.wait([
        _repository.loadSurvey(widget.heritageId, targetYear),
        _repository.fetchAvailableYears(widget.heritageId),
      ]);
      final model = result[0] as SurveyModel?;
      final years = result[1] as List<SurveyYearEntry>;
      if (kDebugMode) {
        print('[HeritageSurveySections] loaded $targetYear '
            'rows=${model?.section12.length ?? 0}');
      }
      setState(() {
        _model = model ?? SurveyModel.empty(targetYear);
        _years = _mergeYears(years, targetYear);
        _loading = false;
        _hasChanges = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('[HeritageSurveySections] load error: $e');
      }
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('조사 데이터 로드 실패: $e')),
      );
    }
  }

  List<SurveyYearEntry> _mergeYears(List<SurveyYearEntry> remote, String active) {
    final seen = {for (final item in remote) item.year: item};
    if (!seen.containsKey(active)) {
      seen[active] = SurveyYearEntry(year: active, hasData: _model != null);
    }
    final list = seen.values.toList()
      ..sort((a, b) => int.parse(b.year).compareTo(int.parse(a.year)));
    return list;
  }

  void _onSection11Changed(Section11Data value) {
    if (_model == null) return;
    setState(() {
      _model = _model!.copyWith(section11: value);
      _hasChanges = true;
    });
  }

  void _onSection12Changed(List<Section12Row> rows) {
    if (_model == null) return;
    setState(() {
      _model = _model!.copyWith(section12: rows);
      _hasChanges = true;
    });
  }

  void _onSection13Changed(Section13Data value) {
    if (_model == null) return;
    setState(() {
      _model = _model!.copyWith(section13: value);
      _hasChanges = true;
    });
  }

  Future<void> _handleSave() async {
    if (_model == null || !_canSave) return;
    setState(() => _saving = true);
    try {
      await _repository.saveSurvey(
        widget.heritageId,
        _activeYear,
        _model!,
        editorUid: Env.defaultEditorUid,
        adminOverride: !_isCurrentYear && _adminOverrideGate,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _hasChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('조사 결과를 저장했습니다.')),
      );
      await _load(year: _activeYear);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  Future<void> _handleImport() async {
    final pastYears = _years.where((y) => y.year != _currentYear).toList();
    if (pastYears.isEmpty || !_importEnabled) return;
    var selected = pastYears.first.year;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(stringsKo['import_confirm_title']!),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(stringsKo['import_confirm_body']!),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selected,
                    items: pastYears
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.year,
                            child: Text('${item.year}년'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selected = value);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('불러오기'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    setState(() => _importing = true);
    try {
      await _repository.importFromYear(
        widget.heritageId,
        selected,
        _activeYear,
        editorUid: Env.defaultEditorUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$selected년 데이터를 적용했습니다.')),
      );
      setState(() {
        _importing = false;
        _editing = true;
      });
      await _load(year: _activeYear);
      setState(() {
        _editing = true;
        _hasChanges = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('불러오기 실패: $e')));
    }
  }

  Future<void> _openHistory() async {
    final items = _years
        .map(
          (entry) => YearHistoryItem(
            year: entry.year,
            hasData: entry.hasData,
            updatedAt: entry.updatedAt,
            isCurrentYear: entry.year == _currentYear,
          ),
        )
        .toList();
    final selected = await showYearHistoryPicker(
      context: context,
      items: items,
      activeYear: _activeYear,
    );
    if (selected != null && selected != _activeYear) {
      await _load(year: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_model == null) {
      return const SizedBox.shrink();
    }

    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Chip(label: Text('$_activeYear년 조사')),
            const SizedBox(width: 8),
            if (!_isCurrentYear)
              Chip(
                backgroundColor: const Color(0xFFFFF4E5),
                label: Text(stringsKo['read_only_banner']!),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_isCurrentYear)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(stringsKo['read_only_banner']!),
          ),
        if (!_isCurrentYear && _allowOverride)
          SwitchListTile.adaptive(
            title: const Text('관리자 수정 허용'),
            subtitle: const Text('필요 시 과거 연도도 편집하며 감사 로그가 상세 기록됩니다.'),
            value: _adminOverrideGate,
            onChanged: (value) {
              setState(() {
                _adminOverrideGate = value;
                if (!value) {
                  _editing = false;
                }
              });
            },
          ),
        Section11Investigation(
          data: _model!.section11,
          enabled: _canEdit,
          onChanged: _onSection11Changed,
        ),
        const SizedBox(height: 16),
        Section12Conservation(
          rows: _model!.section12,
          enabled: _canEdit,
          onChanged: _onSection12Changed,
        ),
        const SizedBox(height: 16),
        Section13Management(
          data: _model!.section13,
          enabled: _canEdit,
          onChanged: _onSection13Changed,
        ),
        const SizedBox(height: 16),
        _buildActions(),
      ],
    );

    return sections;
  }

  Widget _buildActions() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _openHistory,
              icon: const Icon(Icons.history),
              label: Text(stringsKo['history']!),
            ),
            FilledButton.tonalIcon(
              onPressed: _importEnabled ? _handleImport : null,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(stringsKo['import_prev']!),
            ),
            const SizedBox(width: 24),
            FilledButton.icon(
              onPressed: _canSave ? _handleSave : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(stringsKo['save']!),
            ),
            OutlinedButton(
              onPressed:
                  !_canEdit && (_isCurrentYear || _adminOverrideGate)
                      ? () => setState(() {
                            _editing = true;
                            _hasChanges = false;
                          })
                      : null,
              child: Text(stringsKo['edit']!),
            ),
            TextButton.icon(
              onPressed: widget.onNavigateList,
              icon: const Icon(Icons.list_alt),
              label: Text(stringsKo['list']!),
            ),
          ],
        ),
      ),
    );
  }
}
