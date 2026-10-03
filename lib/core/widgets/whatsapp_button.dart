import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

enum WhatsAppButtonSize {
  /// A pill inside a card, e.g. "ابعت تأكيد".
  small,

  /// A row action, e.g. "فكّره".
  regular,

  /// A page's main action, e.g. "ابعت على الواتساب".
  large,
}

/// The only buttons painted in WhatsApp green: each one opens WhatsApp.
///
/// [outlined] is for secondary actions next to other buttons.
class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({
    required this.label,
    required this.onPressed,
    this.size = WhatsAppButtonSize.regular,
    this.outlined = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final WhatsAppButtonSize size;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (height, radius, padding, fontSize, iconSize) = switch (size) {
      WhatsAppButtonSize.small => (36.0, AppRadii.pill, 12.0, 13.0, 16.0),
      WhatsAppButtonSize.regular => (48.0, AppRadii.md, 16.0, 16.0, 20.0),
      WhatsAppButtonSize.large => (56.0, AppRadii.lg, 20.0, 18.0, 22.0),
    };
    final foreground = outlined ? colors.whatsappDeep : colors.onWhatsapp;
    return Material(
      color: outlined ? colors.surface : colors.whatsapp,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: outlined
            ? BorderSide(color: colors.whatsappOutline, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: iconSize,
                  color: foreground,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
