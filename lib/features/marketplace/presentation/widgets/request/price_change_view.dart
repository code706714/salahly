import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/launch/launch_feedback.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/pull_to_refresh.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technician's new price, to approve or decline.
class PriceChangeView extends StatelessWidget {
  const PriceChangeView({required this.details, super.key});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final lines = details.job?.items ?? const <PriceLine>[];
    final technician = firstNameOf(
      details.chosenOffer?.technician.name ?? '',
    );
    // What the consumer pays if they decline: the lines agreed before.
    // When the technician raised an agreed line instead of adding one,
    // every line counts as new: the agreed price is the offer's.
    final kept = lines
        .where((line) => !line.addedLater)
        .fold(0, (sum, line) => sum + line.totalPiastres);
    final agreed = kept > 0 ? kept : details.chosenOffer?.pricePiastres ?? 0;
    return Scaffold(
      appBar: DetailHeader(title: l10n.priceChangeTitle(technician)),
      body: PullToRefresh(
        onRefresh: () => context.read<RequestCubit>().refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Lines(
              lines: lines,
              totalPiastres: details.job?.totalPiastres ?? 0,
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.inkSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: colors.ink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.priceChangeShield(honorific, formatPounds(agreed)),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _Answer(
        details: details,
        technician: technician,
        agreedPiastres: agreed,
      ),
    );
  }
}

/// The agreed lines, the new ones highlighted, and the new total.
class _Lines extends StatelessWidget {
  const _Lines({required this.lines, required this.totalPiastres});

  final List<PriceLine> lines;
  final int totalPiastres;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            _Line(
              label: line.addedLater
                  ? l10n.priceChangeNewLine(_title(line))
                  : l10n.priceChangeAgreedLine(_title(line)),
              amount: formatPounds(line.totalPiastres),
              isNew: line.addedLater,
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l10n.priceChangeNewTotal,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.pounds(formatPounds(totalPiastres)),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _title(PriceLine line) =>
      line.quantity == 1 ? line.title : '${line.title} × ${line.quantity}';
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.amount, required this.isNew});

  final String label;
  final String amount;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isNew ? colors.primaryPressed : colors.ink;
    return ColoredBox(
      color: isNew ? colors.attentionRow : colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: isNew ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Approving, declining after a confirmation, or calling the technician
/// first. Says how it went, since the screen moves on by itself.
class _Answer extends StatelessWidget {
  const _Answer({
    required this.details,
    required this.technician,
    required this.agreedPiastres,
  });

  final RequestDetails details;
  final String technician;
  final int agreedPiastres;

  Future<void> _approve(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final honorific = context.readHonorific();
    final total = formatPounds(details.job?.totalPiastres ?? 0);
    final approved = await context.read<RequestCubit>().answerPriceChange(
      approve: true,
    );
    if (!approved) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.priceChangeApproved(honorific, total, technician)),
        ),
      );
  }

  Future<void> _decline(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final honorific = context.readHonorific();
    final cubit = context.read<RequestCubit>();
    final danger = context.appColors.danger;
    final agreed = formatPounds(agreedPiastres);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.priceChangeDeclineQuestion(honorific)),
        content: Text(l10n.priceChangeDeclineBody(honorific, agreed)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.back),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: danger),
            child: Text(l10n.priceChangeDecline(honorific)),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    if (!await cubit.answerPriceChange(approve: false)) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.priceChangeDeclined(honorific, agreed, technician),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final busy = context.select<RequestCubit, RequestAction?>(
      (cubit) => cubit.state.busy,
    );
    final idle = busy == null;
    final phone = PhoneNumber.tryParse(details.technicianPhone ?? '');
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    );
    const label = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );
    return BottomActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BusyFilledButton(
            label: l10n.priceChangeApprove(
              formatPounds(details.job?.totalPiastres ?? 0),
            ),
            isBusy: busy == RequestAction.approvePrice,
            onPressed: idle ? () => _approve(context) : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (phone != null) ...[
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => context.dial(phone),
                    icon: const Icon(Icons.call_outlined, size: 20),
                    label: Text(l10n.priceChangeCall(honorific)),
                    style: TextButton.styleFrom(
                      backgroundColor: colors.inkSoft,
                      foregroundColor: colors.ink,
                      minimumSize: const Size.fromHeight(48),
                      shape: rounded,
                      textStyle: label,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: idle ? () => _decline(context) : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.danger,
                    minimumSize: const Size.fromHeight(48),
                    shape: rounded,
                    side: BorderSide(color: colors.dangerOutline, width: 1.5),
                    textStyle: label,
                  ),
                  child: busy == RequestAction.declinePrice
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.danger,
                          ),
                        )
                      : Text(l10n.priceChangeDecline(honorific)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
