import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_cross_app/core/services/survey_repository.dart';
import 'package:my_cross_app/core/widgets/year_history_sheet.dart';
import 'package:my_cross_app/models/survey_models.dart';
import 'detail_sections_strings_ko.dart';
import 'section11_investigation.dart';
import 'section12_conservation.dart';
import 'section13_management.dart';

class SurveySectionsPanel extends StatefulWidget {
  final String assetId;
  final String currentYear;
  final String editorUid;

  const SurveySectionsPanel({
    super.key,
    required this.assetId,
    required this.currentYear,
    required this.editorUid,
  });

  @override
  State<SurveySectionsPanel> createState() => _SurveySectionsPanelState();
}

class _SurveySectionsPanelState extends State<SurveySectionsPanel> {
  final SurveyRepository _repository = SurveyRepository();
  
  SurveyModel? _model;
  List<String> _availableYears = [];
  String _activeYear = '';
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isReadOnly = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _activeYear = widget.currentYear;
    _load();
  }

  Future<void> _load({String? year}) async {
    if (kDebugMode) {
      print('[SurveySectionsPanel] Loading survey for asset: ${widget.assetId}, year: ${year ?? _activeYear}');
    }

    setState(() {
      _isLoading = true;
      _activeYear = year ?? _activeYear;
      _isReadOnly = _activeYear != widget.currentYear;
    });

    try {
      // Load available years
      _availableYears = await _repository.getAvailableYears(widget.assetId);
      
      // Load survey data
      _model = await _repository.loadSurvey(widget.assetId, _activeYear);
      
      if (_model == null && _activeYear == widget.currentYear) {
        // Create empty model for current year
        _model = SurveyModel(
          year: _activeYear,
          section11: Section11Data.empty(),
          section12: [],
          section13: Section13Data.empty(),
        );
      }

      if (kDebugMode) {
        print('[SurveySectionsPanel] Loaded model: ${_model != null}');
        print('[SurveySectionsPanel] Available years: $_availableYears');
        print('[SurveySectionsPanel] Is read-only: $_isReadOnly');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SurveySectionsPanel] Error loading survey: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 로드 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_model == null || _isReadOnly) return;

    if (kDebugMode) {
      print('[SurveySectionsPanel] Saving survey for asset: ${widget.assetId}, year: $_activeYear');
    }

    setState(() => _isSaving = true);

    try {
      await _repository.saveSurvey(
        widget.assetId,
        _activeYear,
        _model!,
        editorUid: widget.editorUid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('조사 결과를 저장했습니다.')),
        );
        setState(() {
          _hasChanges = false;
        });
        await _load(); // Reload to get updated data
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SurveySectionsPanel] Error saving survey: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _importFromYear() async {
    if (_activeYear != widget.currentYear) return;

    final availablePastYears = _availableYears
        .where((year) => year != widget.currentYear)
        .toList();

    if (availablePastYears.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('불러올 수 있는 과거 데이터가 없습니다.')),
      );
      return;
    }

    final sourceYear = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stringsKo['import_confirm_title']!),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stringsKo['import_confirm_body']!),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: availablePastYears.first,
              decoration: const InputDecoration(
                labelText: '불러올 연도 선택',
                border: OutlineInputBorder(),
              ),
              items: availablePastYears.map((year) {
                return DropdownMenuItem(
                  value: year,
                  child: Text(year),
                );
              }).toList(),
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, availablePastYears.first),
            child: const Text('불러오기'),
          ),
        ],
      ),
    );

    if (sourceYear == null) return;

    try {
      await _repository.importFromYear(
        widget.assetId,
        sourceYear,
        widget.currentYear,
        editorUid: widget.editorUid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이전 연도 데이터를 불러왔습니다.')),
        );
        await _load();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SurveySectionsPanel] Error importing survey: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('불러오기 실패: $e')),
        );
      }
    }
  }

  void _showYearHistory() {
    showModalBottomSheet(
      context: context,
      builder: (context) => YearHistorySheet(
        availableYears: _availableYears,
        currentYear: widget.currentYear,
        onYearSelected: (year) {
          _load(year: year);
        },
      ),
    );
  }

  void _onSection11Changed(Section11Data value) {
    if (_model == null) return;
    setState(() {
      _model = _model!.copyWith(section11: value);
      _hasChanges = true;
    });
  }

  void _onSection12Changed(List<Section12Row> value) {
    if (_model == null) return;
    setState(() {
      _model = _model!.copyWith(section12: value);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_model == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '데이터를 불러올 수 없습니다.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _load(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Action bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              if (_isReadOnly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    stringsKo['read_only_banner']!,
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '현재 연도: $_activeYear',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _showYearHistory,
                icon: const Icon(Icons.history),
                label: Text(stringsKo['history']!),
              ),
              const SizedBox(width: 8),
              if (_activeYear == widget.currentYear)
                OutlinedButton.icon(
                  onPressed: _importFromYear,
                  icon: const Icon(Icons.download),
                  label: Text(stringsKo['import_prev']!),
                ),
              const SizedBox(width: 8),
              if (!_isReadOnly)
                FilledButton.icon(
                  onPressed: _hasChanges ? _save : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(stringsKo['save']!),
                ),
            ],
          ),
        ),
        
        // Sections
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Section11Investigation(
                  data: _model!.section11,
                  onChanged: _onSection11Changed,
                  enabled: !_isReadOnly,
                ),
                const SizedBox(height: 16),
                Section12Conservation(
                  rows: _model!.section12,
                  onChanged: _onSection12Changed,
                  enabled: !_isReadOnly,
                ),
                const SizedBox(height: 16),
                Section13Management(
                  data: _model!.section13,
                  onChanged: _onSection13Changed,
                  enabled: !_isReadOnly,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}