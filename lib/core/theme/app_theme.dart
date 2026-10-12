import 'package:flutter/material.dart';

/// My Garage Hero brand palette.
class BrandColors {
  const BrandColors._();

  // Brand colours (supplied).
  static const yellow = Color(0xFFEBC565);
  static const lightGrey = Color(0xFFF3F3F3);
  static const white = Color(0xFFFFFFFF);
  static const charcoal = Color(0xFF17191C);

  // Derived tones for a dark automotive UI.
  static const surface = Color(0xFF1E2125);
  static const surfaceRaised = Color(0xFF262A2F);
  static const surfaceHigh = Color(0xFF2F343A);
  static const outline = Color(0xFF353A41);
  static const muted = Color(0xFF9AA1A9);
  static const faint = Color(0xFF6B727A);
  static const yellowDeep = Color(0xFFC79E3F);
  static const yellowSoft = Color(0x26EBC565);

  // Status colours (used sparingly).
  static const success = Color(0xFF4FD08C);
  static const caution = Color(0xFFFFA24A);
  static const danger = Color(0xFFFF5E55);
  static const info = Color(0xFF7DB7FF);

  static const yellowGradient = LinearGradient(
    colors: [Color(0xFFF4D98C), yellow, yellowDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  const AppTheme._();

  static const radius = 22.0;
  static const tabular = [FontFeature.tabularFigures()];

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: BrandColors.yellow,
      onPrimary: BrandColors.charcoal,
      secondary: BrandColors.lightGrey,
      onSecondary: BrandColors.charcoal,
      error: BrandColors.danger,
      onError: BrandColors.white,
      surface: BrandColors.charcoal,
      onSurface: BrandColors.white,
      surfaceContainerLowest: BrandColors.charcoal,
      surfaceContainerLow: BrandColors.surface,
      surfaceContainer: BrandColors.surface,
      surfaceContainerHigh: BrandColors.surfaceRaised,
      surfaceContainerHighest: BrandColors.surfaceHigh,
      onSurfaceVariant: BrandColors.muted,
      outline: BrandColors.outline,
      outlineVariant: BrandColors.outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BrandColors.charcoal,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = base.textTheme.apply(
      bodyColor: BrandColors.lightGrey,
      displayColor: BrandColors.white,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.4),
        bodySmall: text.bodySmall?.copyWith(
          color: BrandColors.muted,
          height: 1.35,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.charcoal,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: BrandColors.white,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: BrandColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: BrandColors.outline, width: 0.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.yellow,
          foregroundColor: BrandColors.charcoal,
          disabledBackgroundColor: BrandColors.surfaceHigh,
          disabledForegroundColor: BrandColors.faint,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.white,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: BrandColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.yellow,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: BrandColors.yellowSoft,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? BrandColors.yellow
                : BrandColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? BrandColors.yellow
                : BrandColors.muted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BrandColors.yellow, width: 1.2),
        ),
        labelStyle: const TextStyle(color: BrandColors.muted),
        hintStyle: const TextStyle(color: BrandColors.faint),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: BrandColors.surfaceRaised,
        side: const BorderSide(color: BrandColors.outline),
        labelStyle: const TextStyle(color: BrandColors.lightGrey, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: BrandColors.outline,
        thickness: 0.6,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.surfaceHigh,
        contentTextStyle: TextStyle(color: BrandColors.white),
        behavior: SnackBarBehavior.floating,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? BrandColors.yellow
                : BrandColors.surfaceRaised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? BrandColors.charcoal
                : BrandColors.lightGrey,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: BrandColors.outline),
          ),
        ),
      ),
    );
  }
}
