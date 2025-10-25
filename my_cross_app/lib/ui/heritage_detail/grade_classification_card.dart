import 'package:flutter/material.dart';

import '../../models/heritage_detail_models.dart';
import '../../theme.dart';
import '../widgets/grade_badge.dart';
import '../widgets/section_title.dart';

class GradeClassificationCard extends StatelessWidget {
  const GradeClassificationCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final GradeClassification value;
  final ValueChanged<GradeClassification> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = value.summary ?? '조사자 의견을 입력하면 자동으로 요약됩니다.';

    return Card(
      margin: EdgeInsets.zero,
      elevation: AppTheme.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: AppTheme.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              title: '등급 분류',
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value.grade,
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('A')),
                    DropdownMenuItem(value: 'B', child: Text('B')),
                    DropdownMenuItem(value: 'C', child: Text('C')),
                    DropdownMenuItem(value: 'D', child: Text('D')),
                    DropdownMenuItem(value: 'E', child: Text('E')),
                  ],
                  onChanged: (newGrade) {
                    if (newGrade == null) return;
                    onChanged(value.copyWith(grade: newGrade));
                  },
                  icon: const Icon(Icons.arrow_drop_down),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final content = [
                  Expanded(
                    flex: 3,
                    child: _SummaryPanel(description: description),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _GradePanel(value: value)),
                ];
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GradePanel(value: value),
                    const SizedBox(height: 16),
                    _SummaryPanel(description: description),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.tableDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '조사자 종합의견',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _GradePanel extends StatelessWidget {
  const _GradePanel({required this.value});

  final GradeClassification value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradeColor = AppTheme.gradeColors[value.grade] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gradeColor, width: 2),
        color: gradeColor.withValues(alpha: 0.1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GradeBadge(grade: value.grade, size: 72),
          const SizedBox(height: 12),
          Text(
            '손상등급 ${value.grade}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: gradeColor,
            ),
          ),
          if (value.label != null) ...[
            const SizedBox(height: 8),
            Text(
              value.label!,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: gradeColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
