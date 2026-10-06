import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';

/// A technician's initials in a brass ring, as offers and their page show
/// them.
class TechnicianAvatar extends StatelessWidget {
  const TechnicianAvatar({
    required this.name,
    required this.size,
    this.ring = 2,
    super.key,
  });

  final String name;

  /// The whole avatar, ring included.
  final double size;
  final double ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        color: context.appColors.brass,
        shape: BoxShape.circle,
      ),
      child: InitialsAvatar(name: name, size: size - 2 * ring),
    );
  }
}
