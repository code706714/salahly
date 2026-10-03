import 'package:flutter/material.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The offers to choose from, sortable, each opening its technician.
class OffersView extends StatelessWidget {
  const OffersView({required this.details, super.key});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(title: AppLocalizations.of(context).requestTitle),
    );
  }
}
