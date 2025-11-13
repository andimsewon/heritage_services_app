import 'package:flutter/material.dart';

/// Apple-style design system with soft sky blue/azure color palette
class AppTheme {
  const AppTheme._();

  // Apple-style Color Palette (Sky Blue / Azure tones)
  static const Color primaryBackground = Color(0xFFFFFFFF); // Pure white
  static const Color secondaryBackground = Color(
    0xFFF5F7FA,
  ); // Soft light gray-blue
  static const Color surfaceTranslucent = Color(
    0xB3FFFFFF,
  ); // Translucent white (70% opacity)

  // Primary text colors
  static const Color primaryText = Color(0xFF1D1D1F); // Apple's primary text
  static const Color secondaryText = Color(
    0xFF6E6E73,
  ); // Apple's secondary text

  // Professional Blue accent colors (business-appropriate, calm and professional)
  static const Color accentBlue = Color(0xFF2563EB); // Professional Blue 600 - 차분하고 전문적
  static const Color accentSkyBlue = Color(0xFF2563EB); // Primary accent (unified)
  static const Color accentAzure = Color(0xFF1E40AF); // Blue 700 - 더 진한 강조
  static const Color accentLightBlue = Color(
    0xFFEFF6FF,
  ); // Blue 50 - 매우 연한 배경

  // Section/Area separation colors
  static const Color sectionBackground = Color(
    0xFFF0F4F8,
  ); // Light blue-gray for sections
  static const Color navigationBackground = Color(
    0xFFE8F0F7,
  ); // Soft blue for navigation
  static const Color buttonPrimary = Color(0xFF2563EB); // Primary button - Professional Blue
  static const Color buttonSecondary = Color(0xFF1E40AF); // Secondary button - Darker Blue
  static const Color borderSubtle = Color(
    0x1A000000,
  ); // Subtle border (10% black)

  // Legacy colors (for compatibility)
  static const Color primaryBlue = Color(0xFF1F4E79);
  static const Color sectionBorder = Color(0xFF40658A);
  static const Color tableHeaderBackground = Color(0xFFF6F8FA);
  static const Color tableRowAlt = Color(0xFFF0F3F6);
  static const Color tableDivider = Color(0xFFE0E6EB);

  // Apple-style Design Tokens
  static const double cardRadius = 20.0; // Larger, softer corners
  static const double buttonRadius = 12.0; // Apple-style button radius
  static const double cardElevation = 0.0; // No elevation, use shadows instead
  static const double blurRadius = 30.0; // Backdrop blur radius

  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 24,
  );

  static const EdgeInsets sectionTitlePadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );

  static const double sectionGap = 32; // More generous spacing
  static const double denseGap = 20;

  // Animation durations (Apple-style: 180-240ms)
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const Curve animationCurve = Curves.easeOut;

  static const Map<String, Color> gradeColors = {
    'A': Color(0xFF4CAF50),
    'B': Color(0xFF8BC34A),
    'C1': Color(0xFFFFC107),
    'C2': Color(0xFFFF9800),
    'D': Color(0xFFFF5722),
    'E': Color(0xFFF44336),
    'F': Color(0xFFD32F2F),
  };

  /// System font fallbacks (Apple-style: SF Pro Display/Text)
  static const List<String> koreanFontFallback = [
    '-apple-system',
    'BlinkMacSystemFont',
    'SF Pro Display',
    'SF Pro Text',
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'Malgun Gothic',
    'Roboto',
    'sans-serif',
  ];

  /// Apple-style border radius
  static const BorderRadius uiRadius = BorderRadius.all(
    Radius.circular(buttonRadius),
  );

  /// Builds Apple-style light theme
  static ThemeData light({bool isWeb = false}) {
    final base = ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final colorScheme = ColorScheme.light(
      primary: accentBlue,
      secondary: accentSkyBlue,
      surface: primaryBackground,
      error: const Color(0xFFFF3B30),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: primaryText,
      onError: Colors.white,
      outline: borderSubtle,
      outlineVariant: borderSubtle,
    );

    final textTheme = _buildAppleTextTheme(base.textTheme, isWeb: isWeb);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: primaryBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: surfaceTranslucent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: primaryText,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 17,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: primaryText, size: 22),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        color: primaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        thickness: 0.5,
        color: borderSubtle,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accentLightBlue,
        selectedColor: accentBlue,
        disabledColor: const Color(0xFFE5E5E7),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFFE5E5E7);
            }
            return buttonPrimary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFF8E8E93);
            }
            return Colors.white;
          }),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return 0;
            }
            if (states.contains(WidgetState.hovered)) {
              return 2;
            }
            return 0;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          animationDuration: animationDuration,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFFE5E5E7);
            }
            return buttonPrimary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFF8E8E93);
            }
            return Colors.white;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          animationDuration: animationDuration,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return accentLightBlue;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFF8E8E93);
            }
            return accentBlue;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: Color(0xFFE5E5E7));
            }
            return const BorderSide(color: accentBlue, width: 1);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          animationDuration: animationDuration,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFF8E8E93);
            }
            return accentBlue;
          }),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          animationDuration: animationDuration,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accentBlue,
        selectionColor: Color(0x330071E3),
        selectionHandleColor: accentBlue,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
      borderSide: BorderSide(color: borderSubtle, width: 1),
    );

    return InputDecorationTheme(
      isDense: false,
      filled: true,
      fillColor: primaryBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: accentBlue, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 2),
      ),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w400,
        color: secondaryText,
        fontSize: 16,
      ),
      hintStyle: const TextStyle(color: secondaryText, fontSize: 16),
    );
  }

  /// Apple-style typography (SF Pro Display/Text inspired)
  static TextTheme _buildAppleTextTheme(TextTheme base, {required bool isWeb}) {
    final applied = base.apply(
      fontFamilyFallback: koreanFontFallback,
      bodyColor: primaryText,
      displayColor: primaryText,
    );

    final preferredFont = isWeb ? '-apple-system' : null;

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
        fontWeight: weight ?? style.fontWeight ?? FontWeight.w400,
        fontSize: size ?? style.fontSize,
        height: height ?? style.height ?? 1.47, // Apple's line-height
        letterSpacing: letterSpacing ?? style.letterSpacing,
      );
    }

    return applied.copyWith(
      // Display styles (large headings)
      displayLarge: applyStyle(
        applied.displayLarge,
        weight: FontWeight.w300, // Light
        size: 64,
        height: 1.05,
        letterSpacing: -1.0,
      ),
      displayMedium: applyStyle(
        applied.displayMedium,
        weight: FontWeight.w300,
        size: 56,
        height: 1.07,
        letterSpacing: -0.8,
      ),
      displaySmall: applyStyle(
        applied.displaySmall,
        weight: FontWeight.w400, // Regular
        size: 48,
        height: 1.08,
        letterSpacing: -0.6,
      ),

      // Headline styles
      headlineLarge: applyStyle(
        applied.headlineLarge,
        weight: FontWeight.w600, // Semibold
        size: 40,
        height: 1.1,
        letterSpacing: -0.4,
      ),
      headlineMedium: applyStyle(
        applied.headlineMedium,
        weight: FontWeight.w600,
        size: 32,
        height: 1.12,
        letterSpacing: -0.3,
      ),
      headlineSmall: applyStyle(
        applied.headlineSmall,
        weight: FontWeight.w600,
        size: 28,
        height: 1.14,
        letterSpacing: -0.2,
      ),

      // Title styles
      titleLarge: applyStyle(
        applied.titleLarge,
        weight: FontWeight.w600,
        size: 22,
        height: 1.27,
        letterSpacing: -0.1,
      ),
      titleMedium: applyStyle(
        applied.titleMedium,
        weight: FontWeight.w600,
        size: 20,
        height: 1.3,
        letterSpacing: -0.05,
      ),
      titleSmall: applyStyle(
        applied.titleSmall,
        weight: FontWeight.w600,
        size: 17,
        height: 1.35,
        letterSpacing: 0,
      ),

      // Body styles
      bodyLarge: applyStyle(
        applied.bodyLarge,
        weight: FontWeight.w400,
        size: 18,
        height: 1.47,
        letterSpacing: 0,
      ),
      bodyMedium: applyStyle(
        applied.bodyMedium,
        weight: FontWeight.w400,
        size: 16,
        height: 1.47,
        letterSpacing: 0,
      ),
      bodySmall: applyStyle(
        applied.bodySmall,
        weight: FontWeight.w400,
        size: 14,
        height: 1.43,
        letterSpacing: 0.1,
      ),

      // Label styles
      labelLarge: applyStyle(
        applied.labelLarge,
        weight: FontWeight.w600,
        size: 16,
        height: 1.38,
        letterSpacing: 0.1,
      ),
      labelMedium: applyStyle(
        applied.labelMedium,
        weight: FontWeight.w500,
        size: 14,
        height: 1.36,
        letterSpacing: 0.2,
      ),
      labelSmall: applyStyle(
        applied.labelSmall,
        weight: FontWeight.w500,
        size: 12,
        height: 1.33,
        letterSpacing: 0.2,
      ),
    );
  }

  /// Apple-style translucent container decoration
  static BoxDecoration translucentContainer({
    Color? color,
    double borderRadius = cardRadius,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? surfaceTranslucent,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ?? Border.all(color: borderSubtle, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Apple-style section background
  static BoxDecoration sectionBackgroundDecoration() {
    return BoxDecoration(
      color: sectionBackground,
      borderRadius: BorderRadius.circular(cardRadius),
    );
  }

  /// Apple-style navigation background
  static BoxDecoration navigationBackgroundDecoration() {
    return BoxDecoration(
      color: navigationBackground,
      borderRadius: BorderRadius.circular(cardRadius),
    );
  }
}
