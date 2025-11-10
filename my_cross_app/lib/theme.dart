import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized design tokens + helpers shared across the heritage experience.
class AppTheme {
  const AppTheme._();

  static const Color primaryBlue = Color(0xFF1F4E79);
  static const Color sectionBorder = Color(0xFF40658A);
  static const Color tableHeaderBackground = Color(0xFFF6F8FA);
  static const Color tableRowAlt = Color(0xFFF0F3F6);
  static const Color tableDivider = Color(0xFFE0E6EB);

  static const double cardRadius = 12;
  static const double cardElevation = 1.5;

  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 20,
  );

  static const EdgeInsets sectionTitlePadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  static const double sectionGap = 24;
  static const double denseGap = 16;

  static const Map<String, Color> gradeColors = {
    'A': Color(0xFF4CAF50),
    'B': Color(0xFF8BC34A),
    'C1': Color(0xFFFFC107), // 주의 - 경미한 손상
    'C2': Color(0xFFFF9800), // 주의 - 중간 손상
    'D': Color(0xFFFF5722),
    'E': Color(0xFFF44336),
    'F': Color(0xFFD32F2F),
  };

  /// System font fallbacks that contain full Hangul glyph sets.
  static const List<String> koreanFontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'Malgun Gothic',
    'Roboto',
    'sans-serif',
  ];

  /// Shared pill radius reused across buttons + text fields.
  static const BorderRadius uiRadius = BorderRadius.all(Radius.circular(10));

  /// Builds the base light theme used across the entire app.
  static ThemeData light({bool isWeb = false}) {
    final base = ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    ).copyWith(
      surface: Colors.white,
      surfaceTint: Colors.white,
      outlineVariant: const Color(0xFFE1E5EC),
    );

    final textTheme = _buildTextTheme(base.textTheme, isWeb: isWeb);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F6FB),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: primaryBlue,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: Color(0xFFE6EAF0)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        color: Color(0xFFE5E9F0),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
        labelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: uiRadius),
          ),
          textStyle: MaterialStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: uiRadius),
          ),
          textStyle: MaterialStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: uiRadius),
          ),
          textStyle: MaterialStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          side: MaterialStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(MaterialState.disabled)
                  ? const Color(0xFFCFD5E1)
                  : primaryBlue,
            ),
          ),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryBlue,
        selectionColor: Color(0x331F4E79),
        selectionHandleColor: primaryBlue,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme) {
    final border = OutlineInputBorder(
      borderRadius: uiRadius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: primaryBlue, width: 1.6),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 1.4),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 1.8),
      ),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        color: Color(0xFF5A6275),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF9DA5B4),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, {required bool isWeb}) {
    final applied = base.apply(
      fontFamilyFallback: koreanFontFallback,
      bodyColor: const Color(0xFF1F2433),
      displayColor: const Color(0xFF111827),
    );

    final preferredFont = isWeb ? 'system-ui' : null;

    TextStyle? applyStyle(
      TextStyle? style, {
      FontWeight? weight,
      double? size,
      double? height,
      double? letterSpacing,
    }) {
      if (style == null) return style;
      return style.copyWith(
        fontFamily: preferredFont,
        fontWeight: weight ?? style.fontWeight,
        fontSize: size ?? style.fontSize,
        height: height ?? style.height ?? 1.36,
        letterSpacing: letterSpacing ?? style.letterSpacing,
      );
    }

    return applied.copyWith(
      headlineLarge: applyStyle(applied.headlineLarge, weight: FontWeight.w700, letterSpacing: -0.6),
      headlineMedium: applyStyle(applied.headlineMedium, weight: FontWeight.w700, letterSpacing: -0.4),
      headlineSmall: applyStyle(applied.headlineSmall, weight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: applyStyle(applied.titleLarge, weight: FontWeight.w700, size: 20, letterSpacing: -0.1),
      titleMedium: applyStyle(applied.titleMedium, weight: FontWeight.w600, size: 17),
      titleSmall: applyStyle(applied.titleSmall, weight: FontWeight.w600, size: 15),
      bodyLarge: applyStyle(applied.bodyLarge, size: 15.5, letterSpacing: -0.2),
      bodyMedium: applyStyle(applied.bodyMedium, size: 14.5),
      bodySmall: applyStyle(applied.bodySmall, size: 13),
      labelLarge: applyStyle(applied.labelLarge, weight: FontWeight.w700, letterSpacing: 0.1),
      labelMedium: applyStyle(applied.labelMedium, weight: FontWeight.w600, letterSpacing: 0.2),
      labelSmall: applyStyle(applied.labelSmall, letterSpacing: 0.2),
    );
  }
}
