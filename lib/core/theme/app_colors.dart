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
    required this.fieldBorder,
    required this.dashedBorder,
    required this.brass,
    required this.whatsapp,
    required this.onWhatsapp,
    required this.dangerDeep,
    required this.dangerFaint,
    required this.dangerLine,
    required this.successBright,
    required this.noticeSoft,
    required this.brassLight,
    required this.onInkFaint,
    required this.chartCollected,
    required this.chartOutstanding,
    required this.whatsappOutline,
    required this.whatsappDeep,
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
    fieldBorder: Color(0xFFD9CDB8),
    dashedBorder: Color(0xFFB9AB93),
    brass: Color(0xFFD69A2D),
    whatsapp: Color(0xFF25D366),
    onWhatsapp: Color(0xFF0B3D1E),
    dangerDeep: Color(0xFF7C1627),
    dangerFaint: Color(0xFFFCF4F5),
    dangerLine: Color(0xFFE8B9C1),
    successBright: Color(0xFF3F7A3A),
    noticeSoft: Color(0xFFFBF3E4),
    brassLight: Color(0xFFE8B65A),
    onInkFaint: Color(0xFF6B7764),
    chartCollected: Color(0xFF8DBF7F),
    chartOutstanding: Color(0xFFE07A88),
    whatsappOutline: Color(0xFF1FA855),
    whatsappDeep: Color(0xFF0B5C2C),
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

  /// Borders of inputs, chips and unchecked boxes.
  final Color fieldBorder;

  /// Dashed outline of empty photo slots.
  final Color dashedBorder;

  /// Accent for highlighted counts on dark surfaces.
  final Color brass;

  /// Reserved for WhatsApp actions only.
  final Color whatsapp;
  final Color onWhatsapp;

  /// Text on [dangerSoft] pills, e.g. overdue.
  final Color dangerDeep;

  /// Background of a card about money owed.
  final Color dangerFaint;

  /// Border of a card about money owed.
  final Color dangerLine;

  /// Completed steps of a progress bar.
  final Color successBright;

  /// Background of the offline notice.
  final Color noticeSoft;

  /// Actions on dark surfaces, e.g. snack bars.
  final Color brassLight;

  /// Outlines on dark surfaces.
  final Color onInkFaint;

  /// Money collected, on dark surfaces.
  final Color chartCollected;

  /// Money still owed, on dark surfaces.
  final Color chartOutstanding;

  /// Border of secondary WhatsApp actions.
  final Color whatsappOutline;

  /// Text of secondary WhatsApp actions.
  final Color whatsappDeep;

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
    Color? fieldBorder,
    Color? dashedBorder,
    Color? brass,
    Color? whatsapp,
    Color? onWhatsapp,
    Color? dangerDeep,
    Color? dangerFaint,
    Color? dangerLine,
    Color? successBright,
    Color? noticeSoft,
    Color? brassLight,
    Color? onInkFaint,
    Color? chartCollected,
    Color? chartOutstanding,
    Color? whatsappOutline,
    Color? whatsappDeep,
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
      fieldBorder: fieldBorder ?? this.fieldBorder,
      dashedBorder: dashedBorder ?? this.dashedBorder,
      brass: brass ?? this.brass,
      whatsapp: whatsapp ?? this.whatsapp,
      onWhatsapp: onWhatsapp ?? this.onWhatsapp,
      dangerDeep: dangerDeep ?? this.dangerDeep,
      dangerFaint: dangerFaint ?? this.dangerFaint,
      dangerLine: dangerLine ?? this.dangerLine,
      successBright: successBright ?? this.successBright,
      noticeSoft: noticeSoft ?? this.noticeSoft,
      brassLight: brassLight ?? this.brassLight,
      onInkFaint: onInkFaint ?? this.onInkFaint,
      chartCollected: chartCollected ?? this.chartCollected,
      chartOutstanding: chartOutstanding ?? this.chartOutstanding,
      whatsappOutline: whatsappOutline ?? this.whatsappOutline,
      whatsappDeep: whatsappDeep ?? this.whatsappDeep,
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
      fieldBorder: Color.lerp(fieldBorder, other.fieldBorder, t)!,
      dashedBorder: Color.lerp(dashedBorder, other.dashedBorder, t)!,
      brass: Color.lerp(brass, other.brass, t)!,
      whatsapp: Color.lerp(whatsapp, other.whatsapp, t)!,
      onWhatsapp: Color.lerp(onWhatsapp, other.onWhatsapp, t)!,
      dangerDeep: Color.lerp(dangerDeep, other.dangerDeep, t)!,
      dangerFaint: Color.lerp(dangerFaint, other.dangerFaint, t)!,
      dangerLine: Color.lerp(dangerLine, other.dangerLine, t)!,
      successBright: Color.lerp(successBright, other.successBright, t)!,
      noticeSoft: Color.lerp(noticeSoft, other.noticeSoft, t)!,
      brassLight: Color.lerp(brassLight, other.brassLight, t)!,
      onInkFaint: Color.lerp(onInkFaint, other.onInkFaint, t)!,
      chartCollected: Color.lerp(chartCollected, other.chartCollected, t)!,
      chartOutstanding: Color.lerp(
        chartOutstanding,
        other.chartOutstanding,
        t,
      )!,
      whatsappOutline: Color.lerp(whatsappOutline, other.whatsappOutline, t)!,
      whatsappDeep: Color.lerp(whatsappDeep, other.whatsappDeep, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
