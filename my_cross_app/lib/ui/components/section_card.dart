import 'package:flutter/material.dart';

/// 공통 섹션 카드 컴포넌트
///
/// 모든 섹션(조사자 의견, 손상부 조사, AI 예측 등)에 사용되는 통일된 디자인 시스템
class SectionCard extends StatelessWidget {
  /// 섹션 제목
  final String title;

  /// 오른쪽 버튼 영역 (저장, 등록, 예측 등)
  final Widget? action;

  /// 본문 내용
  final Widget child;

  /// 내부 여백 (기본값: EdgeInsets.all(18))
  final EdgeInsetsGeometry? padding;

  /// 배경색 (기본값: Colors.white)
  final Color backgroundColor;

  /// 그림자 여부 (기본값: true)
  final bool hasShadow;

  /// 외부 여백 (기본값: EdgeInsets.symmetric(vertical: 10, horizontal: 12))
  final EdgeInsetsGeometry? margin;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.padding,
    this.backgroundColor = Colors.white,
    this.hasShadow = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      padding: padding ?? const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (제목 + 액션 버튼)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C2D5A),
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 14),
          // 본문
          child,
        ],
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
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 40),
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
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF6E7B8A),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
