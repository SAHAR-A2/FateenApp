import 'package:flutter/material.dart';

/// Centralized color palette for the Fateen app.
/// Never hardcode colors in widgets — always reference [AppColors].
class AppColors {
  AppColors._();

  // ---- Brand colors (from Figma) ----
  static const Color primary = Color(0xFF86B0BE);
  static const Color primaryDark = Color(0xFF5F8A98);
  static const Color primaryLight = Color(0xFFB4D0D9);

  static const Color secondary = Color(0xFF59754F);
  static const Color secondaryDark = Color(0xFF3F5638);
  static const Color secondaryLight = Color(0xFF7E9A72);

  static const Color background = Color(0xFFF8F4E9);

  // ---- Semantic / status colors (risk result states) ----
  static const Color success = Color(0xFF3D8B40); // SAFE
  static const Color successSurface = Color(0xFFE7F3E6);

  static const Color warning = Color(0xFFE0A020); // CAUTION
  static const Color warningSurface = Color(0xFFFBF0DD);

  static const Color danger = Color(0xFF9E1B32); // DANGEROUS (matches figma red header)
  static const Color dangerSurface = Color(0xFFFBE6E9);

  static const Color info = Color(0xFF808080); // UNKNOWN / missing info
  static const Color infoSurface = Color(0xFFECECEC);

  // ---- Neutrals ----
  static const Color card = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFDFBF5);
  static const Color border = Color(0xFFE3DDCB);
  static const Color divider = Color(0xFFE8E2D2);

  static const Color textPrimary = Color(0xFF2E2E2E);
  static const Color textSecondary = Color(0xFF6F6F6F);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color disabled = Color(0xFFC9C4B4);

  static const Color favoriteRed = Color(0xFFE0455B);

  /// Returns the correct color set for a given risk state name.
  static Color riskColor(String state) {
    switch (state) {
      case 'safe':
        return success;
      case 'caution':
        return warning;
      case 'dangerous':
        return danger;
      case 'unknown':
      default:
        return info;
    }
  }

  static Color riskSurface(String state) {
    switch (state) {
      case 'safe':
        return successSurface;
      case 'caution':
        return warningSurface;
      case 'dangerous':
        return dangerSurface;
      case 'unknown':
      default:
        return infoSurface;
    }
  }
}
