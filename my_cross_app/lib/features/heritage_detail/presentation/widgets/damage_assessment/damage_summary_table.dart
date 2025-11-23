import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_cross_app/core/services/damage_summary_service.dart';
import 'package:my_cross_app/models/damage_summary_models.dart';

/// 기존 DamageAssessmentSection에서 사용하는 래퍼 위젯
class DamageSummaryTable extends StatelessWidget {
  const DamageSummaryTable({
    super.key,
    required this.heritageId,
    this.sectionNumber,
  });

  final String heritageId;
  final int? sectionNumber;

  @override
  Widget build(BuildContext context) {
    return DamageSummaryPage(
      heritageId: heritageId,
      sectionNumber: sectionNumber,
    );
  }
}

/// 손상부 종합 요약 페이지
class DamageSummaryPage extends StatefulWidget {
  const DamageSummaryPage({
    super.key,
    required this.heritageId,
    this.sectionNumber,
  });

  final String heritageId;
  final int? sectionNumber;

  @override
  State<DamageSummaryPage> createState() => _DamageSummaryPageState();
}

class _DamageSummaryPageState extends State<DamageSummaryPage> {
  final DamageSummaryService _summaryService = DamageSummaryService();

  final Map<String, Map<String, String>> _summary = {};
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  final Map<String, Map<String, bool>> _invalidCells = {};

  Map<String, String> _grades = const {'visual': 'A', 'advanced': 'A'};

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isAutoFilling = false;
  bool _hasChanges = false;
  String? _errorMessage;
  String? _statusMessage;
  Color _statusColor = Colors.blueGrey;

  @override
  void initState() {
    super.initState();
    _initializeState();
    if (widget.heritageId.isNotEmpty) {
      _loadInitialData();
    }
  }

  @override
  void didUpdateWidget(covariant DamageSummaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heritageId != widget.heritageId) {
      _disposeControllers();
      _initializeState();
      if (widget.heritageId.isNotEmpty) {
        _loadInitialData();
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _initializeState() {
    _summary.clear();
    _controllers.clear();
    _invalidCells.clear();

    for (final definition in _damageCategories) {
      _summary[definition.key] = {
        for (final subtype in definition.subtypes) subtype: _defaultOxValue,
      };
      _controllers[definition.key] = {
        for (final subtype in definition.subtypes)
          subtype: TextEditingController(text: _defaultOxValue),
      };
      _invalidCells[definition.key] = {
        for (final subtype in definition.subtypes) subtype: false,
      };
    }

    _grades = const {'visual': 'A', 'advanced': 'A'};
    _errorMessage = null;
    _statusMessage = null;
    _hasChanges = false;
  }

  void _disposeControllers() {
    for (final group in _controllers.values) {
      for (final controller in group.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final saved = await _summaryService.loadSummaryFromFirestore(
        widget.heritageId,
      );
      if (!mounted) return;
      if (saved != null) {
        _applySavedSummary(saved);
      }

      final records = await _summaryService.loadInspectionRecords(
        widget.heritageId,
      );
      if (!mounted) return;
      if (saved == null) {
        _applyAutoSummary(records, markDirty: false);
        _showStatus('손상부 조사 데이터를 기반으로 자동 채워졌습니다.', Colors.blueGrey);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '손상부 종합 데이터를 불러오지 못했습니다. ($e)';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAutoFill() async {
    if (widget.heritageId.isEmpty) return;
    setState(() {
      _isAutoFilling = true;
      _errorMessage = null;
    });

    try {
      final records = await _summaryService.loadInspectionRecords(
        widget.heritageId,
      );
      if (!mounted) return;
      _applyAutoSummary(records, markDirty: true);
      _showStatus('손상부 조사 결과를 새로 반영했습니다.', Colors.indigo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '손상부 조사 데이터를 불러오지 못했습니다. ($e)';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAutoFilling = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    if (widget.heritageId.isEmpty) return;
    if (!_validateBeforeSave()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _summaryService.saveSummaryToFirestore(
        heritageId: widget.heritageId,
        summary: _summary,
        grade: _grades,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });
      _showStatus('손상부 종합을 저장했습니다.', Colors.green.shade600);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = '저장에 실패했습니다. ($e)';
      });
    }
  }

  bool _validateBeforeSave() {
    bool hasError = false;

    setState(() {
      for (final definition in _damageCategories) {
        final key = definition.key;
        final group = _summary[key]!;
        final invalidGroup = _invalidCells[key]!;

        for (final subtype in definition.subtypes) {
          final current = (group[subtype] ?? _defaultOxValue).toUpperCase();
          final isValid = _isValidValue(current);
          invalidGroup[subtype] = !isValid;
          if (!isValid) {
            hasError = true;
          }
          final controller = _controllers[key]![subtype]!;
          if (controller.text != current) {
            controller.text = current;
          }
          group[subtype] = current;
        }
      }

      _errorMessage = hasError ? '모든 항목을 O/X/O 형식으로 입력해 주세요.' : null;
    });

    return !hasError;
  }

  void _applySavedSummary(Map<String, dynamic> summary) {
    setState(() {
      for (final definition in _damageCategories) {
        final key = definition.key;
        final savedMap = Map<String, dynamic>.from(summary[key] as Map? ?? {});
        final group = _summary[key]!;
        final invalidGroup = _invalidCells[key]!;

        for (final subtype in definition.subtypes) {
          final value = _normalizeValue(savedMap[subtype]?.toString());
          group[subtype] = value;
          invalidGroup[subtype] = !_isValidValue(value);
          final controller = _controllers[key]![subtype]!;
          if (controller.text != value) {
            controller.text = value;
          }
        }
      }

      final gradeMap = Map<String, dynamic>.from(
        summary['grade'] as Map? ?? {},
      );
      _grades = {
        'visual': (gradeMap['visual'] ?? 'A').toString(),
        'advanced': (gradeMap['advanced'] ?? 'A').toString(),
      };
      _hasChanges = false;
    });
  }

  void _applyAutoSummary(
    List<DamageRecord> records, {
    required bool markDirty,
  }) {
    final structural = _summaryService.summarizeDamage(
      records
          .where((record) => record.category == DamageCategory.structural)
          .toList(),
    );
    final physical = _summaryService.summarizeDamage(
      records
          .where((record) => record.category == DamageCategory.physical)
          .toList(),
    );
    final biochemical = _summaryService.summarizeDamage(
      records
          .where((record) => record.category == DamageCategory.biochemical)
          .toList(),
    );

    setState(() {
      for (final definition in _damageCategories) {
        final key = definition.key;
        final group = _summary[key]!;
        final invalidGroup = _invalidCells[key]!;
        final controllerGroup = _controllers[key]!;
        final source = _mapByCategoryKey(
          key: key,
          structural: structural,
          physical: physical,
          biochemical: biochemical,
        );

        for (final subtype in definition.subtypes) {
          final value = source[subtype] ?? _defaultOxValue;
          group[subtype] = value;
          invalidGroup[subtype] = !_isValidValue(value);
          final controller = controllerGroup[subtype]!;
          if (controller.text != value) {
            controller.text = value;
          }
        }
      }

      if (markDirty) {
        _hasChanges = true;
      }
    });
  }

  Map<String, String> _mapByCategoryKey({
    required String key,
    required Map<String, String> structural,
    required Map<String, String> physical,
    required Map<String, String> biochemical,
  }) {
    switch (key) {
      case 'physical':
        return physical;
      case 'biochemical':
        return biochemical;
      default:
        return structural;
    }
  }

  void _onCellChanged(String categoryKey, String subtype, String value) {
    final normalized = value.toUpperCase();
    setState(() {
      _summary[categoryKey]![subtype] = normalized;
      _invalidCells[categoryKey]![subtype] = !_isValidValue(normalized);
      _hasChanges = true;
    });
  }

  void _onGradeChanged(String key, String grade) {
    setState(() {
      _grades = {..._grades, key: grade};
      _hasChanges = true;
    });
  }

  void _showStatus(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
  }

  bool _isValidValue(String value) {
    return RegExp(r'^[OX]/[OX]/[OX]$').hasMatch(value);
  }

  String _normalizeValue(String? value) {
    if (value == null) return _defaultOxValue;
    final upper = value.toUpperCase();
    return _isValidValue(upper) ? upper : _defaultOxValue;
  }

  Map<String, List<DamageSubtypeRow>> _buildRowMap() {
    final result = <String, List<DamageSubtypeRow>>{};
    for (final definition in _damageCategories) {
      final key = definition.key;
      final rows = <DamageSubtypeRow>[];
      for (final subtype in definition.subtypes) {
        rows.add(
          DamageSubtypeRow(
            categoryKey: key,
            label: subtype,
            controller: _controllers[key]![subtype]!,
            isInvalid: _invalidCells[key]![subtype] ?? false,
          ),
        );
      }
      result[key] = rows;
    }
    return result;
  }

  Widget _buildToolbar() {
    final saveDisabled = _isSaving || !_hasChanges;
    final buttons = Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: saveDisabled ? null : _handleSave,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            minimumSize: const Size(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? '저장 중...' : '요약 저장'),
        ),
        OutlinedButton.icon(
          onPressed: _isAutoFilling ? null : _handleAutoFill,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            minimumSize: const Size(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _isAutoFilling
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          label: Text(_isAutoFilling ? '동기화 중...' : '손상부 조사 연동'),
        ),
      ],
    );

    final statusLabelText = _hasChanges ? '저장되지 않은 변경 사항이 있습니다.' : '최신 상태입니다.';
    final statusLabelStyle = TextStyle(
      color: _hasChanges ? Colors.redAccent : Colors.green.shade700,
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buttons,
              const SizedBox(height: 12),
              Text(statusLabelText, style: statusLabelStyle),
            ],
          );
        }
        return Row(
          children: [
            buttons,
            const Spacer(),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  statusLabelText,
                  style: statusLabelStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBanner() {
    if (_statusMessage == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.08),
        border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _statusColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color: _statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = Text(
      '손상부 종합 (Damage Summary)',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1D2433),
      ),
    );
    final subtitle = Text(
      '구조적 · 물리적 · 생물·화학적 손상 현황을 좌/중앙/우측 기준으로 정리합니다.',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.sectionNumber != null)
          Container(
            margin: const EdgeInsets.only(right: 16, top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.sectionNumber!.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 4), subtitle],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.heritageId.isEmpty) {
      return const Text('문화재 ID가 필요합니다.');
    }

    final rows = _buildRowMap();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          const Text(
            '· 손상부 조사 결과를 바탕으로 좌/중앙/우측 위치별 손상 여부를 O/X/O로 표기합니다.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 20),
          _buildToolbar(),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            _buildStatusBanner(),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(),
          ],
          const SizedBox(height: 20),
          if (_isLoading)
            _buildLoadingState()
          else
            ResponsiveDamageSummaryWrapper(
              categories: _damageCategories,
              rows: rows,
              onValueChanged: _onCellChanged,
              visualGrade: _grades['visual'] ?? 'A',
              advancedGrade: _grades['advanced'] ?? 'A',
              onVisualGradeChanged: (grade) => _onGradeChanged('visual', grade),
              onAdvancedGradeChanged: (grade) =>
                  _onGradeChanged('advanced', grade),
            ),
        ],
      ),
    );
  }
}

const String _defaultOxValue = 'X/X/X';

const List<DamageCategoryDefinition> _damageCategories = [
  DamageCategoryDefinition(
    key: 'structural',
    title: '구조적 손상',
    headerColor: Color(0xFFE6F1FF),
    badgeColor: Color(0xFF1B4F72),
    subtypes: [
      '변위/변형',
      '이격/이완',
      '기울',
      '들림',
      '축 변형',
      '침하',
      '처짐/휨',
      '비틀림',
      '돌아감',
      '파손/결손',
      '유실',
      '분리',
      '부러짐',
    ],
  ),
  DamageCategoryDefinition(
    key: 'physical',
    title: '물리적 손상',
    headerColor: Color(0xFFEDE7FF),
    badgeColor: Color(0xFF4A3BD0),
    subtypes: ['균열/분할', '균열', '갈래', '표면 박리/박락', '탈락', '들뜸', '박리/박락'],
  ),
  DamageCategoryDefinition(
    key: 'biochemical',
    title: '생물·화학적 손상',
    headerColor: Color(0xFFFFE6EE),
    badgeColor: Color(0xFF9C1047),
    subtypes: [
      '생물/유기물 침식',
      '부후',
      '식물생장',
      '표면 오염균',
      '공극/천공',
      '공동화',
      '천공',
      '재료 변질',
      '변색',
    ],
  ),
];

class DamageCategoryDefinition {
  const DamageCategoryDefinition({
    required this.key,
    required this.title,
    required this.subtypes,
    required this.headerColor,
    required this.badgeColor,
  });

  final String key;
  final String title;
  final List<String> subtypes;
  final Color headerColor;
  final Color badgeColor;
}

class DamageSubtypeRow {
  const DamageSubtypeRow({
    required this.categoryKey,
    required this.label,
    required this.controller,
    required this.isInvalid,
  });

  final String categoryKey;
  final String label;
  final TextEditingController controller;
  final bool isInvalid;
}

typedef CategoryValueChanged =
    void Function(String categoryKey, String subtype, String value);

class ResponsiveDamageSummaryWrapper extends StatelessWidget {
  const ResponsiveDamageSummaryWrapper({
    super.key,
    required this.categories,
    required this.rows,
    required this.onValueChanged,
    required this.visualGrade,
    required this.advancedGrade,
    required this.onVisualGradeChanged,
    required this.onAdvancedGradeChanged,
  });

  final List<DamageCategoryDefinition> categories;
  final Map<String, List<DamageSubtypeRow>> rows;
  final CategoryValueChanged onValueChanged;
  final String visualGrade;
  final String advancedGrade;
  final ValueChanged<String> onVisualGradeChanged;
  final ValueChanged<String> onAdvancedGradeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1100;
        if (isMobile) {
          return DamageSummaryTableMobile(
            categories: categories,
            rows: rows,
            onValueChanged: onValueChanged,
            visualGrade: visualGrade,
            advancedGrade: advancedGrade,
            onVisualGradeChanged: onVisualGradeChanged,
            onAdvancedGradeChanged: onAdvancedGradeChanged,
          );
        }
        return DamageSummaryTableDesktop(
          categories: categories,
          rows: rows,
          onValueChanged: onValueChanged,
          visualGrade: visualGrade,
          advancedGrade: advancedGrade,
          onVisualGradeChanged: onVisualGradeChanged,
          onAdvancedGradeChanged: onAdvancedGradeChanged,
        );
      },
    );
  }
}

class DamageSummaryTableDesktop extends StatelessWidget {
  const DamageSummaryTableDesktop({
    super.key,
    required this.categories,
    required this.rows,
    required this.onValueChanged,
    required this.visualGrade,
    required this.advancedGrade,
    required this.onVisualGradeChanged,
    required this.onAdvancedGradeChanged,
  });

  final List<DamageCategoryDefinition> categories;
  final Map<String, List<DamageSubtypeRow>> rows;
  final CategoryValueChanged onValueChanged;
  final String visualGrade;
  final String advancedGrade;
  final ValueChanged<String> onVisualGradeChanged;
  final ValueChanged<String> onAdvancedGradeChanged;

  static const double _sectionWidth = 420;
  static const double _sectionGap = 16;
  static const double _gradeWidth = 260;

  @override
  Widget build(BuildContext context) {
    final double minWidth =
        (_sectionWidth * categories.length) +
        (_sectionGap * (categories.length - 1)) +
        _gradeWidth +
        24;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < categories.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  right: i == categories.length - 1 ? 0 : _sectionGap,
                ),
                child: SizedBox(
                  width: _sectionWidth,
                  child: DamageCategorySection(
                    definition: categories[i],
                    rows: rows[categories[i].key] ?? const <DamageSubtypeRow>[],
                    onValueChanged: onValueChanged,
                    isCompact: false,
                  ),
                ),
              ),
            const SizedBox(width: 24),
            SizedBox(
              width: _gradeWidth,
              child: GradeTableWidget(
                visualGrade: visualGrade,
                advancedGrade: advancedGrade,
                onVisualGradeChanged: onVisualGradeChanged,
                onAdvancedGradeChanged: onAdvancedGradeChanged,
                isCompact: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DamageSummaryTableMobile extends StatelessWidget {
  const DamageSummaryTableMobile({
    super.key,
    required this.categories,
    required this.rows,
    required this.onValueChanged,
    required this.visualGrade,
    required this.advancedGrade,
    required this.onVisualGradeChanged,
    required this.onAdvancedGradeChanged,
  });

  final List<DamageCategoryDefinition> categories;
  final Map<String, List<DamageSubtypeRow>> rows;
  final CategoryValueChanged onValueChanged;
  final String visualGrade;
  final String advancedGrade;
  final ValueChanged<String> onVisualGradeChanged;
  final ValueChanged<String> onAdvancedGradeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final definition in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 360),
                child: DamageCategorySection(
                  definition: definition,
                  rows: rows[definition.key] ?? const <DamageSubtypeRow>[],
                  onValueChanged: onValueChanged,
                  isCompact: true,
                ),
              ),
            ),
          ),
        GradeTableWidget(
          visualGrade: visualGrade,
          advancedGrade: advancedGrade,
          onVisualGradeChanged: onVisualGradeChanged,
          onAdvancedGradeChanged: onAdvancedGradeChanged,
          isCompact: true,
        ),
      ],
    );
  }
}

class DamageCategorySection extends StatelessWidget {
  const DamageCategorySection({
    super.key,
    required this.definition,
    required this.rows,
    required this.onValueChanged,
    required this.isCompact,
  });

  final DamageCategoryDefinition definition;
  final List<DamageSubtypeRow> rows;
  final CategoryValueChanged onValueChanged;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: definition.badgeColor,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: definition.headerColor.withValues(alpha: 0.8),
        ),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 14 : 18,
              vertical: isCompact ? 10 : 14,
            ),
            decoration: BoxDecoration(
              color: definition.headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Text(definition.title, style: titleStyle),
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1.4),
            },
            border: TableBorder(
              horizontalInside: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [
                  _headerCell('세부 항목', isCompact),
                  _headerCell('좌 / 중앙 / 우측', isCompact),
                ],
              ),
              for (final row in rows)
                TableRow(
                  children: [
                    _labelCell(row.label, isCompact),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 10 : 14,
                        vertical: isCompact ? 6 : 10,
                      ),
                      child: OxCellRenderer(
                        controller: row.controller,
                        isInvalid: row.isInvalid,
                        isCompact: isCompact,
                        onChanged: (value) =>
                            onValueChanged(row.categoryKey, row.label, value),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 8 : 10,
        horizontal: isCompact ? 10 : 14,
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: isCompact ? 12 : 13,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _labelCell(String text, bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 8 : 10,
        horizontal: isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isCompact ? 12 : 13,
          color: const Color(0xFF111827),
        ),
      ),
    );
  }
}

class OxCellRenderer extends StatelessWidget {
  const OxCellRenderer({
    super.key,
    required this.controller,
    required this.isInvalid,
    required this.onChanged,
    required this.isCompact,
  });

  final TextEditingController controller;
  final bool isInvalid;
  final ValueChanged<String> onChanged;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final borderColor = isInvalid ? Colors.redAccent : Colors.grey.shade400;
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      maxLength: 5,
      style: TextStyle(
        fontSize: isCompact ? 12 : 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
      decoration: InputDecoration(
        counterText: '',
        isDense: true,
        hintText: 'X/X/X',
        fillColor: Colors.white,
        filled: true,
        contentPadding: EdgeInsets.symmetric(
          vertical: isCompact ? 6 : 8,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isInvalid ? Colors.redAccent : const Color(0xFF111827),
            width: 1.3,
          ),
        ),
        errorStyle: const TextStyle(height: 0),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[OXox/]')),
        _UpperCaseOxFormatter(),
        LengthLimitingTextInputFormatter(5),
      ],
      onChanged: onChanged,
    );
  }
}

class GradeTableWidget extends StatelessWidget {
  const GradeTableWidget({
    super.key,
    required this.visualGrade,
    required this.advancedGrade,
    required this.onVisualGradeChanged,
    required this.onAdvancedGradeChanged,
    required this.isCompact,
  });

  final String visualGrade;
  final String advancedGrade;
  final ValueChanged<String> onVisualGradeChanged;
  final ValueChanged<String> onAdvancedGradeChanged;
  final bool isCompact;

  static const List<String> _gradeOptions = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF111827),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('손상등급', style: titleStyle),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            columnWidths: const {
              0: FlexColumnWidth(1.6),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [
                  const SizedBox.shrink(),
                  for (final grade in _gradeOptions)
                    _gradeHeaderCell(grade, isCompact),
                ],
              ),
              _buildGradeRow(
                label: '육안',
                background: const Color(0xFFE6F9EE),
                selected: visualGrade,
                onTap: onVisualGradeChanged,
                isCompact: isCompact,
              ),
              _buildGradeRow(
                label: '심화',
                background: const Color(0xFFFFF4E3),
                selected: advancedGrade,
                onTap: onAdvancedGradeChanged,
                isCompact: isCompact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildGradeRow({
    required String label,
    required Color background,
    required String selected,
    required ValueChanged<String> onTap,
    required bool isCompact,
  }) {
    return TableRow(
      children: [
        Container(
          color: background,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 14),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: isCompact ? 12 : 13,
            ),
          ),
        ),
        for (final grade in _gradeOptions)
          _gradeCell(
            grade: grade,
            selected: selected,
            onTap: onTap,
            isCompact: isCompact,
          ),
      ],
    );
  }

  Widget _gradeHeaderCell(String text, bool isCompact) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF4B5563),
          fontSize: isCompact ? 12 : 13,
        ),
      ),
    );
  }

  Widget _gradeCell({
    required String grade,
    required String selected,
    required ValueChanged<String> onTap,
    required bool isCompact,
  }) {
    final isSelected = grade == selected;
    final baseColor = isSelected ? const Color(0xFF1D4ED8) : Colors.white;
    final textColor = isSelected ? Colors.white : const Color(0xFF111827);

    return InkWell(
      onTap: () => onTap(grade),
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 12),
        decoration: BoxDecoration(
          color: baseColor,
          border: Border.all(color: const Color(0xFFCBD5F5)),
        ),
        child: Text(
          grade,
          style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
        ),
      ),
    );
  }
}

class _UpperCaseOxFormatter extends TextInputFormatter {
  const _UpperCaseOxFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(text: upper);
  }
}
