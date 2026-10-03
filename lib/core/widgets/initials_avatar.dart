import 'package:flutter/material.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';

/// A round avatar with a person's initials: "أ. كريم منصور" → "ك م".
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    required this.name,
    this.size = 48,
    this.color,
    super.key,
  });

  final String name;
  final double size;

  /// Defaults to the soft ink color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? colors.inkSoft,
          shape: BoxShape.circle,
        ),
        child: Text(
          initialsOf(name),
          maxLines: 1,
          style: TextStyle(
            fontSize: size / 3,
            fontWeight: FontWeight.w700,
            color: colors.ink,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
