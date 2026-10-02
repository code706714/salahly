import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';

abstract final class AppTheme {
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
      fontFamily: 'IBMPlexSansArabic',
      extensions: const [colors],
    );
  }
}
