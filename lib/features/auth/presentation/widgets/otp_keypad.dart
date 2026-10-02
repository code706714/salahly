import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// The on-screen number pad of the code screen, laid out like a phone's.
class OtpKeypad extends StatelessWidget {
  const OtpKeypad({
    required this.onDigit,
    required this.onDelete,
    required this.deleteLabel,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final String deleteLabel;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ColoredBox(
      color: colors.divider,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in _rows) ...[
                if (row != _rows.first) const SizedBox(height: 8),
                Row(
                  children: [
                    for (final key in row) ...[
                      if (key != row.first) const SizedBox(width: 8),
                      Expanded(child: _key(context, key)),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _key(BuildContext context, String key) {
    if (key.isEmpty) return const SizedBox(height: 56);
    final colors = context.appColors;
    final isDelete = key == '⌫';
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: isDelete ? onDelete : () => onDigit(key),
        child: SizedBox(
          height: 56,
          child: Center(
            child: isDelete
                ? Icon(
                    Icons.backspace_outlined,
                    color: colors.ink,
                    semanticLabel: deleteLabel,
                  )
                : Text(
                    key,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
