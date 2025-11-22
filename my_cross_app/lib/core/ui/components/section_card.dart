import 'package:flutter/material.dart';

/// 공통 섹션 카드 컴포넌트
///
/// 모든 섹션(조사자 의견, 손상부 조사, AI 예측 등)에 사용되는 통일된 디자인 시스템
class SectionCard extends StatelessWidget {
  final String title;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color backgroundColor;
  final bool hasShadow;
  final EdgeInsetsGeometry? margin;
  final int? sectionNumber;
  final String? sectionDescription;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.padding,
    this.backgroundColor = Colors.white,
    this.hasShadow = true,
    this.margin,
    this.sectionNumber,
    this.sectionDescription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1C2D5A),
    );

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: padding ?? const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMobile && action != null) ...[
                // 모바일: 제목과 액션을 세로로 배치
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (sectionNumber != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2A44).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$sectionNumber',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF1E2A44),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: titleStyle,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
                if (sectionDescription != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sectionDescription!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    softWrap: true,
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: action!,
                ),
              ] else ...[
                // 데스크톱: 가로 배치
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (sectionNumber != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2A44).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$sectionNumber',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: const Color(0xFF1E2A44),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Text(
                                  title,
                                  style: titleStyle,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                          if (sectionDescription != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              sectionDescription!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              softWrap: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: action!,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 14),
              child,
            ],
          );
        },
      ),
    );
  }
}

/// 빈 상태 표시용 컨테이너
class EmptyStateContainer extends StatelessWidget {
  final String message;
  final IconData? icon;

  const EmptyStateContainer({
    super.key,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E5EA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFF6E7B8A), size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6E7B8A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
