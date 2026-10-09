import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_theme.dart';

void main() {
  group('AppTheme.light', () {
    test('exposes AppColors and matches the primary color', () {
      final theme = AppTheme.light();

      expect(theme.extension<AppColors>(), AppColors.light);
      expect(theme.colorScheme.primary, AppColors.light.primary);
    });
  });

  group('AppColors.lerp', () {
    test('blends primary at 0.5', () {
      const black = Color(0xFF000000);
      final other = AppColors.light.copyWith(primary: black);

      final result = AppColors.light.lerp(other, 0.5);

      expect(
        result.primary,
        Color.lerp(AppColors.light.primary, black, 0.5),
      );
    });
  });
}
