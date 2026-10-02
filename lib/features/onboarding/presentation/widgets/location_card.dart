import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// The tappable "where are you" card: the chosen area and where it came
/// from, or a prompt to choose one.
class LocationCard extends StatelessWidget {
  const LocationCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isChosen,
    this.hasError = false,
    this.isBusy = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isChosen;
  final bool hasError;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final borderColor = hasError
        ? colors.danger
        : isChosen
        ? colors.primary
        : colors.fieldBorder;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (isBusy)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.location_on_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: colors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
