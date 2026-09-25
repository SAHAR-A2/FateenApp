import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

/// Centralized typography scale. Always use these styles instead of
/// creating inline TextStyle objects — this is what makes a global font
/// swap (see app_fonts.dart) actually take effect everywhere.
///
/// Sizes/weights/letter-spacing here were tuned specifically for Arabic
/// (Cairo) — slightly tighter letter-spacing than Latin defaults, and a
/// touch more line-height for comfortable reading of Arabic diacritics
/// and descenders.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle _base = TextStyle(
    fontFamily: AppFonts.family,
    fontFamilyFallback: AppFonts.fallback,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  /// Hero / splash headline
  static TextStyle headline = _base.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.primary,
  );

  /// Screen titles e.g. "مرحبا بك.." / "الصفحة الشخصية"
  static TextStyle title = _base.copyWith(
    fontSize: 25,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.primary,
  );

  /// Section subtitles e.g. "أنواع الحساسية"
  static TextStyle subtitle = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Standard body text
  static TextStyle body = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMedium = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Small captions e.g. helper text, chip labels
  static TextStyle caption = _base.copyWith(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Button label text
  static TextStyle button = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AppColors.textOnPrimary,
  );

  /// Big result banner text e.g. "تحذير" / "امن"
  static TextStyle resultTitle = _base.copyWith(
    fontSize: 27,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static TextStyle resultDescription = _base.copyWith(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.textSecondary,
  );

  static TextStyle link = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    decoration: TextDecoration.underline,
  );
}
