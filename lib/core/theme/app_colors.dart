import 'package:flutter/material.dart';

/// Brand color tokens, exposed through [ThemeData.extensions].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primaryPressed,
    required this.primarySoft,
    required this.onPrimary,
    required this.ink,
    required this.inkMuted,
    required this.inkSoft,
    required this.onInkMuted,
    required this.background,
    required this.surface,
    required this.border,
    required this.divider,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.whatsapp,
    required this.onWhatsapp,
  });

  static const light = AppColors(
    primary: Color(0xFFB8492C),
    primaryPressed: Color(0xFF8F3520),
    primarySoft: Color(0xFFF3E1D9),
    onPrimary: Color(0xFFFFFCF7),
    ink: Color(0xFF2F3B2A),
    inkMuted: Color(0xFF5E6656),
    inkSoft: Color(0xFFE3E7DC),
    onInkMuted: Color(0xFFD9D2C3),
    background: Color(0xFFF7F2EA),
    surface: Color(0xFFFFFCF7),
    border: Color(0xFFE6DDCD),
    divider: Color(0xFFEFE7DA),
    success: Color(0xFF2E5C2A),
    successSoft: Color(0xFFE4EDE2),
    warning: Color(0xFF7A4C0C),
    warningSoft: Color(0xFFF4E8D2),
    danger: Color(0xFF9B1C31),
    dangerSoft: Color(0xFFF6DDE1),
    whatsapp: Color(0xFF25D366),
    onWhatsapp: Color(0xFF0B3D1E),
  );

  final Color primary;
  final Color primaryPressed;
  final Color primarySoft;
  final Color onPrimary;
  final Color ink;
  final Color inkMuted;
  final Color inkSoft;
  final Color onInkMuted;
  final Color background;
  final Color surface;
  final Color border;
  final Color divider;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  /// Reserved for WhatsApp actions only.
  final Color whatsapp;
  final Color onWhatsapp;

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryPressed,
    Color? primarySoft,
    Color? onPrimary,
    Color? ink,
    Color? inkMuted,
    Color? inkSoft,
    Color? onInkMuted,
    Color? background,
    Color? surface,
    Color? border,
    Color? divider,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? whatsapp,
    Color? onWhatsapp,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkSoft: inkSoft ?? this.inkSoft,
      onInkMuted: onInkMuted ?? this.onInkMuted,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      whatsapp: whatsapp ?? this.whatsapp,
      onWhatsapp: onWhatsapp ?? this.onWhatsapp,
    );
  }

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      onInkMuted: Color.lerp(onInkMuted, other.onInkMuted, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      whatsapp: Color.lerp(whatsapp, other.whatsapp, t)!,
      onWhatsapp: Color.lerp(onWhatsapp, other.onWhatsapp, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
