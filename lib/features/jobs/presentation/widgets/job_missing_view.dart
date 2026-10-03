import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What a job's screens show for a job that is not on this phone, e.g.
/// one deleted since its link was opened.
class JobMissingView extends StatelessWidget {
  const JobMissingView({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(title: title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context).jobPageMissing,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: context.appColors.inkMuted),
          ),
        ),
      ),
    );
  }
}
