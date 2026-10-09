import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Tells the technician their work is saved on the phone while the server
/// is out of reach. Takes no space otherwise, [padding] included.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({this.padding = EdgeInsets.zero, super.key});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final (isOffline, pending) = context.select<SyncCubit, (bool, int)>(
      (cubit) => (cubit.state.isOffline, cubit.state.pendingChanges),
    );
    if (!isOffline) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Padding(
      padding: padding,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.noticeSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.cloud_outlined,
                  size: 18,
                  color: colors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: colors.warning,
                    ),
                    children: [
                      TextSpan(
                        text: l10n.offlineTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' ${l10n.offlinePending(pending)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
