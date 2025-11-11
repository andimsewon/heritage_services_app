import 'package:flutter/material.dart';
import 'package:my_cross_app/core/theme/app_theme.dart';
import 'package:my_cross_app/core/ui/components/section_card.dart';
import 'package:my_cross_app/core/ui/widgets/grade_badge.dart';
import 'package:my_cross_app/models/heritage_detail_models.dart';

class GradeClassificationCard extends StatelessWidget {
  const GradeClassificationCard({
    super.key,
    this.sectionNumber,
    required this.value,
    required this.onChanged,
  });

  final int? sectionNumber;
  final GradeClassification value;
  final ValueChanged<GradeClassification> onChanged;

  String _getGradeTooltip(String grade) {
    switch (grade) {
      case 'A':
        return 'A등급: 양호 - 문화재 보존 상태가 매우 양호하여 별도의 조치가 필요하지 않음';
      case 'B':
        return 'B등급: 양호 - 경미한 손상이 있으나 정기적인 관찰만 필요';
      case 'C1':
        return 'C1등급: 주의 - 경미한 손상이 관찰되며 정기적인 관찰과 예방 조치 필요';
      case 'C2':
        return 'C2등급: 주의 - 중간 정도의 손상이 관찰되며 모니터링 및 예방 조치 필요';
      case 'D':
        return 'D등급: 경고 - 손상이 심화될 가능성이 있어 정밀조사 및 보수 계획 수립 필요';
      case 'E':
        return 'E등급: 심각 - 즉시 보수 또는 긴급 조치가 필요한 상태';
      case 'F':
        return 'F등급: 매우 심각 - 안전상 위험이 있어 즉시 안전 조치 및 긴급 보수 필요';
      default:
        return '문화재 보존 상태 등급을 선택해주세요';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = value.summary ?? '조사자 의견을 입력하면 자동으로 요약됩니다.';

    return SectionCard(
      sectionNumber: sectionNumber,
      title: '등급 분류',
      sectionDescription: '문화재 보존 상태 등급을 분류합니다',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value.grade,
              items: const [
                DropdownMenuItem(value: 'A', child: Text('A')),
                DropdownMenuItem(value: 'B', child: Text('B')),
                DropdownMenuItem(value: 'C1', child: Text('C1')),
                DropdownMenuItem(value: 'C2', child: Text('C2')),
                DropdownMenuItem(value: 'D', child: Text('D')),
                DropdownMenuItem(value: 'E', child: Text('E')),
                DropdownMenuItem(value: 'F', child: Text('F')),
              ],
              onChanged: (newGrade) {
                if (newGrade == null) return;
                onChanged(value.copyWith(grade: newGrade));
              },
              icon: const Icon(Icons.arrow_drop_down),
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _getGradeTooltip(value.grade),
            child: Icon(
              Icons.info_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // constraints.maxWidth가 무한대일 수 있으므로 MediaQuery도 함께 사용
          final screenWidth = MediaQuery.of(context).size.width;
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : screenWidth;
          final isWide = availableWidth >= 720;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _SummaryPanel(description: description),
                ),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: _GradePanel(value: value)),
              ],
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

  String _getGradeComment(String grade) {
    switch (grade) {
      case 'A':
        return '양호 - 별도 조치 필요 없음';
      case 'B':
        return '양호 - 경미한 손상 관찰 필요';
      case 'C1':
        return '주의 - 경미한 손상, 정기적 관찰 필요';
      case 'C2':
        return '주의 - 중간 손상, 모니터링 및 예방 조치 필요';
      case 'D':
        return '경고 - 정밀조사 필요, 손상 심화 가능성';
      case 'E':
        return '심각 - 즉시 보수 또는 긴급 조치 필요';
      case 'F':
        return '매우 심각 - 즉시 안전 조치 및 긴급 보수 필요';
      default:
        return '등급을 선택해주세요';
    }
  }

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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF1E2A44),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getGradeComment(value.grade),
                    style: const TextStyle(
                      color: Color(0xFF1E2A44),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
