import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/dashed_rrect_border.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/complaint_cubit.dart';
import 'package:salahly/features/marketplace/presentation/request_follow_up.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Reporting a problem with a request. Pops `true` once sent.
class ComplaintPage extends StatelessWidget {
  const ComplaintPage({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ComplaintCubit(
          requests: context.read(),
          requestId: requestId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const ComplaintView(),
    );
  }
}

/// The complaint form: the reason, details and a photo.
class ComplaintView extends StatefulWidget {
  const ComplaintView({super.key});

  @override
  State<ComplaintView> createState() => _ComplaintViewState();
}

class _ComplaintViewState extends State<ComplaintView> {
  final _details = TextEditingController();

  static const _detailsLimit = 1000;
  static const _counterFrom = 900;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _showFailure(BuildContext context, ComplaintState state) {
    final l10n = AppLocalizations.of(context);
    final honorific = context.readHonorific();
    final message = switch (state.failure!) {
      AlreadySentFailure() => l10n.complaintOpen,
      UploadLimitFailure() => l10n.complaintPhotoLimit(honorific),
      final failure => consumerFailureMessage(
        l10n,
        failure,
        honorific: honorific,
      ),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final cubit = context.watch<ComplaintCubit>();
    final state = cubit.state;
    final categories = context.watch<CategoriesCubit>().state;
    final request = state.request;
    final technician = request?.chosenOffer?.technician.name;
    return BlocListener<ComplaintCubit, ComplaintState>(
      listener: (context, state) {
        if (state.status == ComplaintStatus.sent) {
          Navigator.of(context).pop(true);
        } else if (state.failure != null) {
          _showFailure(context, state);
        }
      },
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failure != current.failure,
      child: Scaffold(
        appBar: DetailHeader(
          title: l10n.complaintTitle,
          subtitle: request == null || technician == null
              ? null
              : l10n.complaintSubtitle(
                  requestName(
                    l10n,
                    categories,
                    categoryId: request.categoryId,
                    issue: request.issue,
                  ),
                  technician,
                ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.complaintQuestion,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (final reason in ComplaintReason.values) ...[
              if (reason != ComplaintReason.values.first)
                const SizedBox(height: 8),
              _ReasonTile(
                label: _reasonLabel(l10n, reason),
                selected: state.reason == reason,
                onTap: () => cubit.pickReason(reason),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              l10n.complaintDetails,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _details,
              minLines: 3,
              maxLines: 6,
              maxLength: _detailsLimit,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 16, height: 1.6),
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => currentLength >= _counterFrom
                  ? Text('$currentLength/$maxLength')
                  : null,
              decoration: InputDecoration(
                hintText: l10n.complaintDetailsHint,
                hintStyle: TextStyle(fontSize: 16, color: colors.inkMuted),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 14),
            if (state.photo case final photo?)
              _AttachedPhoto(path: photo, onRemove: cubit.removePhoto)
            else
              const _AddPhotoButton(),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: BusyFilledButton(
            label: l10n.complaintSubmit(honorific),
            isBusy: state.status == ComplaintStatus.sending,
            onPressed: state.canSend
                ? () => cubit.send(details: _details.text)
                : null,
          ),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final edge = selected ? colors.primary : colors.border;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      side: BorderSide(color: edge, width: 2),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: selected ? colors.noticeSoft : colors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: edge, width: 2),
                    ),
                    child: selected
                        ? Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 16, color: colors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed button that adds a photo or a screenshot.
class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton();

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final honorific = context.readHonorific();
    final messenger = ScaffoldMessenger.of(context);
    final picker = context.read<PhotoPicker>();
    final cubit = context.read<ComplaintCubit>();
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.complaintPhotoTake(honorific)),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.complaintPhotoChoose(honorific)),
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final path = await picker.pick(
        source: source,
        purpose: PhotoPurpose.request,
      );
      if (path != null && !cubit.isClosed) cubit.attachPhoto(path);
    } on PlatformException {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.complaintPhotoDenied(honorific))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DashedRRectBorder(
      color: colors.dashedBorder,
      radius: AppRadii.md,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  size: 22,
                  color: colors.inkMuted,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    ).complaintAddPhoto(context.watchHonorific()),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The photo that goes with the complaint, with a way to take it off.
class _AttachedPhoto extends StatelessWidget {
  const _AttachedPhoto({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm - 4),
            child: Image.file(
              File(path),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 72,
                height: 72,
                color: colors.border,
                child: Icon(Icons.image_outlined, color: colors.inkMuted),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRemove,
            tooltip: AppLocalizations.of(
              context,
            ).complaintPhotoRemove(context.watchHonorific()),
            icon: Icon(Icons.close_rounded, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

String _reasonLabel(AppLocalizations l10n, ComplaintReason reason) =>
    switch (reason) {
      ComplaintReason.noShowOrLate => l10n.complaintReasonNoShow,
      ComplaintReason.priceRaised => l10n.complaintReasonPriceRaised,
      ComplaintReason.poorWork => l10n.complaintReasonPoorWork,
      ComplaintReason.badConduct => l10n.complaintReasonBadConduct,
      ComplaintReason.other => l10n.complaintReasonOther,
    };
