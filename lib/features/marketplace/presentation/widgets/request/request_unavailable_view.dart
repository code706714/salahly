import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A request that couldn't be shown: gone, or not fetched yet ([missing]
/// false), with a retry.
class RequestUnavailableView extends StatelessWidget {
  const RequestUnavailableView({required this.missing, super.key});

  final bool missing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Scaffold(
      appBar: DetailHeader(title: l10n.requestTitle),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                missing ? l10n.marketplaceNotFound : l10n.requestLoadFailed,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: colors.inkMuted),
              ),
              if (!missing) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: context.read<RequestCubit>().refresh,
                  child: Text(l10n.consumerRetry(context.watchHonorific())),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
