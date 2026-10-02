import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// Six boxes showing the code typed so far; the next box is highlighted.
class OtpCodeBoxes extends StatelessWidget {
  const OtpCodeBoxes({
    required this.code,
    required this.length,
    required this.semanticLabel,
    this.onLongPress,
    super.key,
  });

  final String code;
  final int length;
  final String semanticLabel;

  /// Used to paste a copied code.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: semanticLabel,
      value: code,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        width: 2,
                        color: i == code.length
                            ? colors.primary
                            : i < code.length
                            ? colors.fieldBorder
                            : colors.border,
                      ),
                    ),
                    child: Text(
                      i < code.length ? code[i] : '',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
