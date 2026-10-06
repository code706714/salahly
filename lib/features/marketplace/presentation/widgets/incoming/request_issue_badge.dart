import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';

/// The request's problem as an icon on a tinted square.
class RequestIssueBadge extends StatelessWidget {
  const RequestIssueBadge({required this.issue, super.key});

  final RequestIssue issue;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Icon(_icon, size: 24, color: colors.primary),
    );
  }

  IconData get _icon => switch (issue) {
    RequestIssue.notCooling => Icons.ac_unit_rounded,
    RequestIssue.leaking => Icons.water_drop_outlined,
    RequestIssue.noisy => Icons.volume_up_outlined,
    RequestIssue.needsCleaning => Icons.cleaning_services_outlined,
    RequestIssue.installation => Icons.build_outlined,
    RequestIssue.other => Icons.help_outline_rounded,
  };
}
