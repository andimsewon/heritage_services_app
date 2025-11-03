import 'package:flutter/material.dart';

/// 섹션 카드에서 사용되는 공통 버튼 스타일
class SectionButton {
  /// Outlined 스타일 버튼 (테두리만)
  ///
  /// 주로 부가적인 액션(조사 등록, 지도 생성 등)에 사용
  static OutlinedButton outlined({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color? color,
  }) {
    final buttonColor = color ?? const Color(0xFF1C2D5A);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.add, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: buttonColor,
        side: BorderSide(color: buttonColor),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Filled 스타일 버튼 (배경 채워진)
  ///
  /// 주로 주요 액션(저장, AI 예측 등)에 사용
  static ElevatedButton filled({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.assignment_outlined, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? const Color(0xFF1C2D5A),
        foregroundColor: foregroundColor ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
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
        final row = Row(
          mainAxisAlignment: alignment,
          children: [
            for (int i = 0; i < buttons.length; i++) ...[
              buttons[i],
              if (i < buttons.length - 1) SizedBox(width: spacing),
            ],
          ],
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: row,
          ),
        );
      },
    );
  }
}
