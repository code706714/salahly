import 'package:flutter/material.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The request before any offer arrives: who it went to and widening the time.
class WaitingView extends StatelessWidget {
  const WaitingView({required this.details, super.key});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(title: AppLocalizations.of(context).requestTitle),
    );
  }
}
