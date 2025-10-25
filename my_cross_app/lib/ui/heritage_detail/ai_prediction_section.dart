import 'package:flutter/material.dart';

import '../../models/heritage_detail_models.dart';
import '../../theme.dart';
import '../widgets/section_title.dart';

class AIPredictionSection extends StatefulWidget {
  const AIPredictionSection({
    super.key,
    required this.state,
    required this.actions,
  });

  final AIPredictionState state;
  final AIPredictionActions actions;

  @override
  State<AIPredictionSection> createState() => _AIPredictionSectionState();
}

class _AIPredictionSectionState extends State<AIPredictionSection> {
  _PredictionTab _selected = _PredictionTab.grade;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'AI 예측 기능',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _aiButton(
                context,
                'AI 손상등급 예측',
                Icons.auto_awesome,
                _PredictionTab.grade,
              ),
              _aiButton(
                context,
                '손상지도 생성',
                Icons.map_outlined,
                _PredictionTab.map,
              ),
              _aiButton(
                context,
                '기후변화 대응',
                Icons.cloud_queue,
                _PredictionTab.mitigation,
              ),
              _aiButton(
                context,
                '보고서 생성',
                Icons.description_outlined,
                _PredictionTab.report,
              ),
            ],
          ),
          if (widget.state.loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (widget.state.error != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.state.error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _aiButton(
    BuildContext context,
    String label,
    IconData icon,
    _PredictionTab tab,
  ) {
    final isSelected = _selected == tab;
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 80) / 2,
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _selected = tab),
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? const Color(0xFF2956CC)
              : const Color(0xFFB0B3B9),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.tableDivider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.explore_outlined,
            size: 32,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
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
