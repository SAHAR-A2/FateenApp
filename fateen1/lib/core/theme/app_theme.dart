import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_fonts.dart';

/// ─────────────────────────────────────────────────────────────
/// SIMPLE THEME FILE — everything that controls spacing, rounding,
/// shadows, and the final ThemeData lives in this one file on purpose.
/// Change a number here and it updates everywhere in the app that
/// references it. (Colors live in app_colors.dart, text styles in
/// app_text_styles.dart, font choice in app_fonts.dart — kept separate
/// only because they're edited independently more often.)
/// ─────────────────────────────────────────────────────────────

/// Spacing scale — 4px rhythm. Use these instead of raw numbers.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double smMd = 12;
  static const double md = 16;
  static const double mdLg = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  static const double screenHorizontal = 28;
  static const double screenVertical = 20;
  static const double fieldGap = smMd;
  static const double sectionGap = lg;
  static const double listItemGap = smMd;
  static const double cardPadding = md;
}

/// Corner rounding scale. Change a number here and every
/// button/card/field/dialog using that token updates everywhere.
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 100;

  static const double button = pill;
  static const double textField = pill;
  static const double card = md;
  static const double dialog = lg;
  static const double chip = pill;
}

/// Soft, elegant shadow presets used across cards and buttons.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
  ];
  static List<BoxShadow> card = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> elevated = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 8)),
  ];
}

/// The single ThemeData source for the whole app. [AppFonts.family]
/// cascades to every Text widget automatically — see app_fonts.dart.
class AppTheme {
  AppTheme._();

  static const double buttonHeight = 54;

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppFonts.family,
      fontFamilyFallback: AppFonts.fallback,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextStyles.subtitle,
      ),
      textTheme: TextTheme(
        headlineMedium: AppTextStyles.headline,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.subtitle,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.button,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size.fromHeight(buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: AppTextStyles.button,
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.textField),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.textField),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.textField),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.textField),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.textField),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.secondary,
        contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
      ),
    );
  }
}
