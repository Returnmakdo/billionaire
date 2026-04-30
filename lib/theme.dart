import 'package:flutter/material.dart';

// 웹 styles.css의 CSS 변수와 1:1 매핑
class AppColors {
  static const bg = Color(0xFFF4F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF7F9FB);
  static const text = Color(0xFF191F28);
  static const text2 = Color(0xFF4E5968);
  static const text3 = Color(0xFF8B95A1);
  static const text4 = Color(0xFFB0B8C1);
  static const line = Color(0xFFE5E8EB);
  static const line2 = Color(0xFFF0F2F5);
  static const primary = Color(0xFF3182F6);
  static const primaryWeak = Color(0xFFE8F1FF);
  static const primaryStrong = Color(0xFF1B64DA);
  static const success = Color(0xFF1ABF76);
  static const danger = Color(0xFFF04452);
  static const warning = Color(0xFFF59E0B);
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 22.0;
}

ThemeData buildTheme() {
  const fontFamily = 'Pretendard';
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
      bodyLarge: TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.text2),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
    ).apply(fontFamily: fontFamily),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
