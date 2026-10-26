import 'package:flutter/material.dart';

/// Palette Pubulotron.
class PubColors {
  static const violet = Color(0xFF7545FF);
  static const rose = Color(0xFFFF6384);
  static const orange = Color(0xFFFFAA45);
  static const turquoise = Color(0xFF24C9C2);
  static const night = Color(0xFF17213B);
  static const white = Color(0xFFF8F7FC);

  static const brandGradient = LinearGradient(
    colors: [violet, rose, orange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const coolGradient = LinearGradient(
    colors: [violet, turquoise],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class PubTheme {
  static const fontFamily = 'Ubuntu';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: PubColors.violet,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFA98BFF) : PubColors.violet,
          onPrimary: dark ? PubColors.night : Colors.white,
          secondary: PubColors.turquoise,
          onSecondary: PubColors.night,
          tertiary: PubColors.rose,
          error: const Color(0xFFE5484D),
          surface: dark ? const Color(0xFF121A2F) : PubColors.white,
          onSurface: dark ? const Color(0xFFEDEBFA) : PubColors.night,
          surfaceContainerLowest: dark ? const Color(0xFF0C1324) : Colors.white,
          surfaceContainerLow: dark
              ? const Color(0xFF16203A)
              : const Color(0xFFF2F0FB),
          surfaceContainer: dark
              ? const Color(0xFF1B2643)
              : const Color(0xFFECE9F8),
          surfaceContainerHigh: dark
              ? const Color(0xFF222E4F)
              : const Color(0xFFE5E1F5),
          surfaceContainerHighest: dark
              ? const Color(0xFF2A375B)
              : const Color(0xFFDDD8F1),
          outlineVariant: dark
              ? const Color(0xFF34406A)
              : const Color(0xFFD6D1EC),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
    );
    final radius = BorderRadius.circular(16);
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
    );
  }
}
