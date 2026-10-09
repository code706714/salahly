import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

abstract final class AppTheme {
  static const fontFamily = 'IBMPlexSansArabic';

  static ThemeData light() {
    const colors = AppColors.light;
    final colorScheme = ColorScheme.light(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.ink,
      onSecondary: colors.surface,
      error: colors.danger,
      onError: colors.onPrimary,
      surface: colors.surface,
      onSurface: colors.ink,
    );
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      fontFamily: fontFamily,
      extensions: const [colors],
      textTheme: _textTheme(colors),
      inputDecorationTheme: _inputDecorationTheme(colors),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.inkMuted,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.inkMuted,
          minimumSize: const Size(48, 44),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: colors.background,
          fontSize: 15,
          height: 1.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.background,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xxl),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static TextTheme _textTheme(AppColors colors) {
    return TextTheme(
      // Page titles.
      headlineSmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: colors.ink,
      ),
      // Section titles inside a page.
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.5,
        color: colors.ink,
      ),
      // Card titles and app bar titles.
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.5,
        color: colors.ink,
      ),
      // Field labels.
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: colors.ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: colors.ink),
      // Hints and secondary lines.
      bodySmall: TextStyle(fontSize: 13, height: 1.5, color: colors.inkMuted),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(AppColors colors) {
    OutlineInputBorder border(Color color, {double width = 1.5}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(colors.fieldBorder),
      enabledBorder: border(colors.fieldBorder),
      focusedBorder: border(colors.primary, width: 2),
      errorBorder: border(colors.danger),
      focusedErrorBorder: border(colors.danger, width: 2),
      hintStyle: TextStyle(color: colors.inkMuted, fontSize: 17),
      errorStyle: TextStyle(color: colors.danger, fontSize: 13),
    );
  }
}
