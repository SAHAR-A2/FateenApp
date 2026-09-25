import 'package:flutter/material.dart';

class AppTheme {
  static const Color cream = Color(0xFFF6F1E4); // الخلفية الكريمية
  static const Color teal = Color(
    0xFF6FA6AF,
  ); // التركوازي الأساسي (حدود، نص، أزرار)
  static const Color darkTeal = Color(0xFF5A8F98); // للعناوين الكبيرة
  static const Color chipGray = Color(0xFFECECEC); // خلفية حبات الاختيار
  static const Color chipText = Color(0xFF5A5A5A); // نص حبات الاختيار
  static const Color white = Colors.white;

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: cream,
      fontFamily: 'Tajawal',
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: darkTeal,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: darkTeal, width: 2),
        ),
        hintStyle: const TextStyle(color: teal),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
