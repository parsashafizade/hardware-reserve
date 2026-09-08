import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand50 = Color(0xFFEEF7FF);
  static const brand100 = Color(0xFFD8EDFF);
  static const brand200 = Color(0xFFB9DDFF);
  static const brand300 = Color(0xFF86C5FF);
  static const brand400 = Color(0xFF4AA3FF);
  static const brand500 = Color(0xFF247FF2);
  static const brand600 = Color(0xFF1767DC);
  static const brand700 = Color(0xFF1553B2);
  static const brand800 = Color(0xFF17478F);
  static const brand950 = Color(0xFF0D2448);
  static const ink950 = Color(0xFF07111F);
  static const ink900 = Color(0xFF111C2C);
  static const ink700 = Color(0xFF324155);
  static const ink600 = Color(0xFF46566A);
  static const ink500 = Color(0xFF617287);
  static const canvas = Color(0xFFF2F6FB);
  static const muted = Color(0xFFEAF1F8);
  static const border = Color(0xFFD7E2EE);
  static const inverse = Color(0xFF081526);
  static const inverseRaised = Color(0xFF0F2238);
  static const success = Color(0xFF0F9F73);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC3F5D);
  static const info = Color(0xFF1975DC);
}

abstract final class AppTheme {
  static const controlRadius = 14.0;
  static const cardRadius = 20.0;
  static const panelRadius = 28.0;

  static ThemeData light(Locale locale) {
    final isPersian = locale.languageCode == 'fa';
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand600,
        brightness: Brightness.light,
        primary: AppColors.brand600,
        secondary: AppColors.info,
        surface: Colors.white,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: isPersian ? 'Vazir' : null,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );
    final body = base.textTheme.apply(
      bodyColor: AppColors.ink900,
      displayColor: AppColors.ink950,
      fontFamily: isPersian ? 'Vazir' : null,
    );
    final headingFamily = isPersian ? 'Sahel' : null;
    final textTheme = body.copyWith(
      displayLarge: body.displayLarge?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: body.displayMedium?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: body.headlineLarge?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: body.headlineMedium?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: body.titleLarge?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontFamily: headingFamily,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: body.bodyLarge?.copyWith(height: 1.65),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.6),
    );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas.withValues(alpha: .96),
        foregroundColor: AppColors.ink950,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 19),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.brand100,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.brand500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: const TextStyle(color: AppColors.ink600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: rounded,
          textStyle: textTheme.labelLarge?.copyWith(
            fontFamily: headingFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: rounded,
          side: const BorderSide(color: AppColors.border),
          foregroundColor: AppColors.ink700,
          textStyle: textTheme.labelLarge?.copyWith(
            fontFamily: headingFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: rounded,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        backgroundColor: Colors.white,
        selectedColor: AppColors.brand100,
        side: const BorderSide(color: AppColors.border),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: AppColors.border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        backgroundColor: AppColors.inverseRaised,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}
