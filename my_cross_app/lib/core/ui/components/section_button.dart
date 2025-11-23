import 'package:flutter/material.dart';

/// 섹션 카드에서 사용되는 공통 버튼 스타일
class SectionButton {
  /// Outlined 스타일 버튼 (테두리만)
  ///
  /// 주로 부가적인 액션(조사 등록, 지도 생성 등)에 사용
  static Widget outlined({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color? color,
  }) {
    final lightPink = Color(0xFFFFE0E6); // 연한 핑크 배경
    final redBorder = Color(0xFFFF6B9D); // 빨간 테두리
    final redText = Color(0xFFFF4757); // 빨간 텍스트

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 32, // 최소 클릭 영역 보장
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: lightPink,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: redBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: redText),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: redText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Filled 스타일 버튼 (배경 채워진)
  ///
  /// 주로 주요 액션(저장, AI 예측 등)에 사용
  static Widget filled({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final bgColor = backgroundColor ?? const Color(0xFF1C2D5A);
    final fgColor = foregroundColor ?? Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 32, // 최소 클릭 영역 보장
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fgColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Text 스타일 버튼 (배경 없음)
  ///
  /// 주로 보조적인 액션(취소, 닫기 등)에 사용
  static TextButton text({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color? color,
  }) {
    final buttonColor = color ?? const Color(0xFF1C2D5A);

    return TextButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// IconButton 스타일 (아이콘만)
  ///
  /// 주로 작은 액션(편집, 삭제 등)에 사용
  static IconButton icon({
    required IconData iconData,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
    double size = 20,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(iconData, size: size),
      color: color ?? const Color(0xFF1C2D5A),
      tooltip: tooltip,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

/// 버튼 그룹 래퍼 (여러 버튼을 나란히 배치)
class SectionButtonGroup extends StatelessWidget {
  final List<Widget> buttons;
  final double spacing;
  final MainAxisAlignment alignment;

  const SectionButtonGroup({
    super.key,
    required this.buttons,
    this.spacing = 8,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        if (isMobile) {
          // 모바일: Wrap을 사용하여 자동 줄바꿈
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.start,
            children: buttons,
          );
        } else {
          // 데스크톱: 가로 배치 (스크롤 없이, 버튼 크기 유지)
          return Row(
            mainAxisAlignment: alignment,
            children: [
              for (int i = 0; i < buttons.length; i++) ...[
                buttons[i],
                if (i < buttons.length - 1) SizedBox(width: spacing),
              ],
            ],
          );
        }
      },
    );
  }
}
