import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_theme.dart';

/// The app's theme with the few controls a desktop console has more of,
/// such as switches, drawn in the app's own colours.
ThemeData adminTheme() {
  const colors = AppColors.light;
  return AppTheme.light().copyWith(
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(colors.surface),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.success
            : colors.dashedBorder,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
