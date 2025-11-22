import 'package:flutter/material.dart';
import 'package:my_cross_app/core/theme/app_theme.dart';
import 'package:my_cross_app/core/ui/widgets/section_title.dart';
import 'package:my_cross_app/models/heritage_detail_models.dart';

class AIPredictionSection extends StatefulWidget {
  const AIPredictionSection({
    super.key,
    this.sectionNumber,
    required this.state,
    required this.actions,
  });

  final int? sectionNumber;
  final AIPredictionState state;
  final AIPredictionActions actions;

  @override
  State<AIPredictionSection> createState() => _AIPredictionSectionState();
}

class _AIPredictionSectionState extends State<AIPredictionSection> {
  _PredictionTab _selected = _PredictionTab.grade;

  @override
  Widget build(BuildContext context) {
    final sectionTitle = widget.sectionNumber != null
        ? '${widget.sectionNumber}. AI 예측'
        : 'AI 예측';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI를 활용한 손상 등급 예측 및 분석',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final crossAxisCount = isMobile ? 1 : 2;
              
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: isMobile ? 4.0 : 2.6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _aiButton(
                    'AI 손상등급 예측',
                    Icons.auto_awesome,
                    _PredictionTab.grade,
                  ),
                  _aiButton(
                    '손상지도 생성',
                    Icons.map_outlined,
                    _PredictionTab.map,
                  ),
                  _aiButton(
                    '기후변화 대응',
                    Icons.cloud_outlined,
                    _PredictionTab.mitigation,
                  ),
                  _aiButton(
                    '보고서 생성',
                    Icons.description_outlined,
                    _PredictionTab.report,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (widget.state.loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 20),
          ],
          if (widget.state.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                widget.state.error!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _aiButton(
    String label,
    IconData icon,
    _PredictionTab tab,
  ) {
    final isSelected = _selected == tab;
    return ElevatedButton.icon(
      onPressed: () => setState(() => _selected = tab),
      icon: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : const Color(0xFF1F2937),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF1F2937),
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xFF2C3E8C)
            : const Color(0xFFF3F4F6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_selected) {
      case _PredictionTab.grade:
        return _PredictionPane(
          key: const ValueKey('grade'),
          buttonLabel: '✦ 생성',
          buttonTooltip: 'AI 손상등급 예측 실행',
          onGenerate: widget.actions.onPredictGrade,
          disabled: widget.state.loading,
          child: _buildGradeContent(context),
        );
      case _PredictionTab.map:
        return _PredictionPane(
          key: const ValueKey('map'),
          buttonLabel: '✦ 생성',
          buttonTooltip: 'AI 손상지도 생성 실행',
          onGenerate: widget.actions.onGenerateMap,
          disabled: widget.state.loading,
          child: _buildMapContent(context),
        );
      case _PredictionTab.mitigation:
        return _PredictionPane(
          key: const ValueKey('mitigation'),
          buttonLabel: '✦ 생성',
          buttonTooltip: '기후변화 적용관리 방안 도출',
          onGenerate: widget.actions.onSuggest,
          disabled: widget.state.loading,
          child: _buildMitigationContent(context),
        );
      case _PredictionTab.report:
        return _PredictionPane(
          key: const ValueKey('report'),
          buttonLabel: '✦ 생성',
          buttonTooltip: '보고서 생성',
          onGenerate: () {},
          disabled: widget.state.loading,
          child: const _PlaceholderCard(
            message: '보고서 생성 기능은 준비 중입니다.',
          ),
        );
    }
  }

  Widget _buildGradeContent(BuildContext context) {
    final grade = widget.state.grade;
    if (grade == null) {
      return const _PlaceholderCard(message: '예측 결과가 없습니다. ✦ 생성 버튼을 눌러 예측하세요.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '예상 손상등급 변화',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _GradePreview(
                      title: '현재 등급 \${grade.from}',
                      image: grade.before,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _YearsArrow(
                      years: grade.years,
                      direction: Axis.horizontal,
                    ),
                  ),
                  Expanded(
                    child: _GradePreview(
                      title: '예상 등급 \${grade.to}',
                      image: grade.after,
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GradePreview(
                  title: '현재 등급 \${grade.from}',
                  image: grade.before,
                ),
                const SizedBox(height: 12),
                _YearsArrow(years: grade.years, direction: Axis.vertical),
                const SizedBox(height: 12),
                _GradePreview(title: '예상 등급 \${grade.to}', image: grade.after),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMapContent(BuildContext context) {
    final map = widget.state.map;
    if (map == null) {
      return const _PlaceholderCard(
        message: '생성된 손상지도가 없습니다. ✦ 생성 버튼을 눌러 주세요.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '히트맵 프리뷰',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image(image: map, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }

  Widget _buildMitigationContent(BuildContext context) {
    final mitigations = widget.state.mitigations;
    if (mitigations == null || mitigations.isEmpty) {
      return const _PlaceholderCard(message: '적용관리 방안이 없습니다. ✦ 생성 버튼을 눌러 주세요.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '예상 대응 시나리오',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(color: AppTheme.tableDivider),
          columnWidths: const {
            0: FlexColumnWidth(1.5),
            1: FlexColumnWidth(2.5),
          },
          children: [
            const TableRow(
              decoration: BoxDecoration(color: AppTheme.tableHeaderBackground),
              children: [
                _MitigationHeaderCell(text: '기후 요인'),
                _MitigationHeaderCell(text: '적용관리 방안'),
              ],
            ),
            for (final item in mitigations)
              TableRow(
                decoration: const BoxDecoration(color: Colors.white),
                children: [
                  _MitigationCell(text: item.factor),
                  _MitigationCell(text: item.action),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

enum _PredictionTab { grade, map, mitigation, report }

class _PredictionPane extends StatelessWidget {
  const _PredictionPane({
    super.key,
    required this.child,
    required this.buttonLabel,
    required this.buttonTooltip,
    required this.onGenerate,
    required this.disabled,
  });

  final Widget child;
  final String buttonLabel;
  final String buttonTooltip;
  final VoidCallback onGenerate;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: buttonTooltip,
            child: FilledButton(
              onPressed: disabled ? null : onGenerate,
              child: Text(buttonLabel),
            ),
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.explore_outlined,
            size: 28,
            color: Color(0xFF2C3E8C),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradePreview extends StatelessWidget {
  const _GradePreview({required this.title, required this.image});

  final String title;
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image(image: image, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}

class _YearsArrow extends StatelessWidget {
  const _YearsArrow({required this.years, required this.direction});

  final int years;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Icon(
        direction == Axis.horizontal
            ? Icons.arrow_forward
            : Icons.arrow_downward,
        color: AppTheme.primaryBlue,
      ),
      Text('$years년 후', style: Theme.of(context).textTheme.bodyMedium),
    ];
    if (direction == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [children[0], const SizedBox(width: 8), children[1]],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [children[0], const SizedBox(height: 8), children[1]],
    );
  }
}

class _MitigationHeaderCell extends StatelessWidget {
  const _MitigationHeaderCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MitigationCell extends StatelessWidget {
  const _MitigationCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
