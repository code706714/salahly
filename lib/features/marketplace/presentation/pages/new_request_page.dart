import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_back_button.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/core/widgets/dashed_rrect_border.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/request_draft.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/addresses_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/new_request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/address_form_sheet.dart';
import 'package:salahly/features/marketplace/presentation/widgets/address_summary.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asking for a technician: the problem, photos, the address and the time.
///
/// Starts on [categoryId] when given; [technicianId] sends the request to
/// that technician first.
class NewRequestPage extends StatelessWidget {
  const NewRequestPage({this.categoryId, this.technicianId, super.key});

  final String? categoryId;
  final String? technicianId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final categories = context.read<CategoriesCubit>();
        // Retries the catalog if it couldn't be fetched at start.
        unawaited(categories.load());
        final cubit = NewRequestCubit(
          requests: context.read(),
          speech: context.read(),
          categoryId: categoryId,
          technicianId: technicianId,
        )..useCategories(categories.state.categories);
        unawaited(cubit.start());
        return cubit;
      },
      child: const NewRequestView(),
    );
  }
}

class NewRequestView extends StatefulWidget {
  const NewRequestView({super.key});

  @override
  State<NewRequestView> createState() => _NewRequestViewState();
}

class _NewRequestViewState extends State<NewRequestView> {
  late final _description = TextEditingController(
    text: context.read<NewRequestCubit>().state.description,
  );

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _showFailure(Failure failure) {
    final l10n = AppLocalizations.of(context);
    final honorific = context.readHonorific();
    final message = switch (failure) {
      InvalidTimeFailure() => l10n.newRequestInvalidTime(honorific),
      UploadLimitFailure() => l10n.newRequestUploadLimit(honorific),
      UnsupportedPhotoFailure() => l10n.newRequestPhotoRejected(honorific),
      _ => consumerFailureMessage(l10n, failure, honorific: honorific),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewRequestCubit>();
    final state = context.watch<NewRequestCubit>().state;
    final sent = state.sent;

    return MultiBlocListener(
      listeners: [
        BlocListener<CategoriesCubit, CategoriesState>(
          listener: (context, categories) =>
              cubit.useCategories(categories.categories),
        ),
        BlocListener<NewRequestCubit, NewRequestState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == NewRequestStatus.failed) {
              _showFailure(state.failure!);
            }
            // The home banner and "طلباتي" show the new request; fetching
            // them also brings the requests left up to date.
            if (state.status == NewRequestStatus.sent) {
              unawaited(context.read<MyRequestsCubit>().load());
            }
          },
        ),
        BlocListener<NewRequestCubit, NewRequestState>(
          // Dictated words land in the field; typed ones are already there.
          listenWhen: (previous, current) =>
              current.description != _description.text,
          listener: (context, state) => _description.value = TextEditingValue(
            text: state.description,
            selection: TextSelection.collapsed(
              offset: state.description.length,
            ),
          ),
        ),
      ],
      child: PopScope(
        canPop:
            sent != null ||
            (state.step == NewRequestStep.problem && !state.isSending),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) cubit.back();
        },
        child: Scaffold(
          appBar: _Header(state: state),
          body: sent != null
              ? _SentStep(sent: sent, category: state.category?.name ?? '')
              : state.category == null
              ? const Center(child: CircularProgressIndicator())
              : switch (state.step) {
                  NewRequestStep.problem => _ProblemStep(
                    state: state,
                    description: _description,
                  ),
                  NewRequestStep.address => _AddressStep(state: state),
                  NewRequestStep.time => _TimeStep(state: state),
                },
          bottomNavigationBar: BottomActionBar(
            child: sent != null
                ? const _BackHomeButton()
                : _NextButton(state: state),
          ),
        ),
      ),
    );
  }
}

/// Back, the title, how far along the form is, and the step bars.
class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header({required this.state});

  final NewRequestState state;

  @override
  Size get preferredSize => const Size.fromHeight(91);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final category = state.category;
    final done = state.sent != null;
    final reached = done ? 3 : state.step.index + 1;
    return Material(
      color: colors.background,
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AppBackButton(
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          category == null
                              ? l10n.newRequestTitleAny(honorific)
                              : l10n.newRequestTitle(honorific, category.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Text(
                        done
                            ? l10n.newRequestDone
                            : l10n.newRequestStep(reached),
                        style: TextStyle(fontSize: 14, color: colors.inkMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      for (var bar = 1; bar <= 3; bar++) ...[
                        if (bar > 1) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: bar <= reached
                                  ? colors.primary
                                  : colors.border,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ],
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

/// A step's question: "إيه المشكلة؟".
class _StepTitle extends StatelessWidget {
  const _StepTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

/// What is missing, under the part of the step it is about.
class _Missing extends StatelessWidget {
  const _Missing(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(fontSize: 13, color: context.appColors.danger),
    ),
  );
}

class _ProblemStep extends StatelessWidget {
  const _ProblemStep({required this.state, required this.description});

  final NewRequestState state;
  final TextEditingController description;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final cubit = context.read<NewRequestCubit>();
    final technician = state.technician;
    final descriptionMissing =
        state.showsErrors &&
        state.needsDescription &&
        state.description.trim().isEmpty;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      children: [
        if (technician != null) ...[
          _FirstTechnician(technician: technician),
          const SizedBox(height: 16),
        ],
        _StepTitle(l10n.newRequestIssueTitle),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final issue in RequestIssue.values)
              ChoiceChipButton(
                label: requestIssueLabel(l10n, issue),
                selected: state.issue == issue,
                onTap: () => cubit.selectIssue(issue),
              ),
          ],
        ),
        if (state.showsErrors && state.issue == null) ...[
          const SizedBox(height: 8),
          _Missing(l10n.newRequestIssueRequired(honorific)),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.newRequestDescription,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: description,
          onChanged: cubit.editDescription,
          minLines: 3,
          maxLines: 6,
          maxLength: NewRequestCubit.maxDescriptionLength,
          keyboardType: TextInputType.multiline,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => currentLength >= NewRequestCubit.maxDescriptionLength - 100
              ? Text('$currentLength/$maxLength')
              : null,
          style: const TextStyle(fontSize: 16, height: 1.6),
          decoration: InputDecoration(
            hintText: l10n.newRequestDescriptionHint,
            hintStyle: TextStyle(fontSize: 16, color: colors.inkMuted),
            contentPadding: const EdgeInsets.all(12),
            errorText: descriptionMissing
                ? l10n.newRequestDescriptionRequired(honorific)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        _DictateButton(isListening: state.isListening),
        const SizedBox(height: 16),
        Text(
          l10n.newRequestPhotos,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final photo in state.photos) _PhotoTile(path: photo),
            if (state.photos.length < NewRequestCubit.maxPhotos)
              const _AddPhotoTile(),
          ],
        ),
      ],
    );
  }
}

/// The technician asked again, who gets the request before anyone else.
class _FirstTechnician extends StatelessWidget {
  const _FirstTechnician({required this.technician});

  final TechnicianCard technician;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.inkSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            name: technician.name,
            size: 44,
            color: colors.surface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.newRequestFirstTechnician(technician.name),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                Text(
                  l10n.newRequestFirstTechnicianNote,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DictateButton extends StatelessWidget {
  const _DictateButton({required this.isListening});

  final bool isListening;

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(
      context,
    ).newRequestSpeechUnavailable(context.readHonorific());
    final listening = await context.read<NewRequestCubit>().toggleListening();
    if (listening) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    return DashedRRectBorder(
      color: colors.primary,
      radius: AppRadii.md,
      child: Material(
        color: isListening ? colors.primarySoft : colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () => _toggle(context),
          child: SizedBox(
            height: 52,
            child: Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                    color: colors.primaryPressed,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      isListening
                          ? l10n.newRequestListening(honorific)
                          : l10n.newRequestDictate(honorific),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.primaryPressed,
                      ),
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

const _photoSize = 88.0;
const _photoRadius = 12.0;

/// A picked photo, with a button to take it out.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return SizedBox.square(
      dimension: _photoSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_photoRadius),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: colors.border,
                  child: Center(
                    child: Text(
                      l10n.newRequestPhoto,
                      style: TextStyle(fontSize: 12, color: colors.inkMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton(
              onPressed: () =>
                  context.read<NewRequestCubit>().removePhoto(path),
              tooltip: l10n.newRequestRemovePhoto(context.watchHonorific()),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: colors.ink.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colors.surface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dashed tile that picks a photo from the camera or the gallery.
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile();

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final honorific = context.readHonorific();
    final messenger = ScaffoldMessenger.of(context);
    final picker = context.read<PhotoPicker>();
    final cubit = context.read<NewRequestCubit>();
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.newRequestPhotoTake(honorific)),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.newRequestPhotoChoose(honorific)),
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final String? path;
    try {
      path = await picker.pick(source: source, purpose: PhotoPurpose.request);
    } on PlatformException {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.newRequestCameraDenied(honorific))),
        );
      return;
    }
    if (path != null) cubit.addPhoto(path);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      label: AppLocalizations.of(
        context,
      ).newRequestAddPhoto(context.watchHonorific()),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _photoSize,
        child: DashedRRectBorder(
          color: colors.dashedBorder,
          radius: _photoRadius,
          child: InkWell(
            borderRadius: BorderRadius.circular(_photoRadius),
            onTap: () => _pick(context),
            child: Center(
              child: Icon(
                Icons.photo_camera_outlined,
                size: 24,
                color: colors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressStep extends StatelessWidget {
  const _AddressStep({required this.state});

  final NewRequestState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final cubit = context.read<NewRequestCubit>();
    final addresses = state.addresses;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      children: [
        _StepTitle(l10n.newRequestAddressTitle),
        const SizedBox(height: 12),
        if (addresses == null && state.addressesFailed) ...[
          Text(
            l10n.addressesLoadFailed,
            style: TextStyle(fontSize: 15, color: colors.inkMuted),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: cubit.loadAddresses,
              style: TextButton.styleFrom(foregroundColor: colors.primary),
              child: Text(l10n.consumerRetry(honorific)),
            ),
          ),
          const SizedBox(height: 12),
        ] else if (addresses == null) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
        ] else
          for (final address in addresses) ...[
            _AddressOption(
              address: address,
              selected: address.id == state.addressId,
              onTap: () => cubit.selectAddress(address.id),
            ),
            const SizedBox(height: 12),
          ],
        if (addresses != null &&
            addresses.length >= AddressesCubit.maxAddresses)
          Text(
            l10n.consumerAddressLimit(honorific),
            style: TextStyle(fontSize: 14, color: colors.inkMuted),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ChoiceChipButton(
              label: l10n.addressesNew,
              icon: Icons.add_rounded,
              selected: false,
              onTap: () => showAddressForm(context, onSave: cubit.addAddress),
            ),
          ),
        if (state.showsErrors && !state.addressDone) ...[
          const SizedBox(height: 8),
          _Missing(l10n.newRequestAddressRequired(honorific)),
        ],
        const SizedBox(height: 12),
        const _PrivacyNote(),
      ],
    );
  }
}

/// An address to pick, with a radio mark.
class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final ConsumerAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: AppCard(
        radius: AppRadii.lg,
        padding: const EdgeInsets.all(14),
        borderColor: selected ? colors.primary : colors.border,
        borderWidth: selected ? 2 : 1.5,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.primary : colors.inkMuted,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: AddressSummary(address: address)),
          ],
        ),
      ),
    );
  }
}

/// Technicians see the area only, until the consumer picks one of them.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.inkSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 22, color: colors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              ).addressesPrivacy(context.watchHonorific()),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeStep extends StatelessWidget {
  const _TimeStep({required this.state});

  final NewRequestState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final honorific = context.watchHonorific();
    final cubit = context.read<NewRequestCubit>();
    final day = state.day;
    const windows = RequestWindow.choices;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      children: [
        _StepTitle(l10n.newRequestTimeTitle),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, choice) in state.days.indexed)
              ChoiceChipButton(
                label: _dayLabel(l10n, choice, index),
                selected: choice == day,
                onTap: state.hasOpenWindow(choice)
                    ? () => cubit.selectDay(choice)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (var row = 0; row < windows.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (final (index, window) in windows.indexed)
                if (index ~/ 2 == row ~/ 2) ...[
                  if (index > row) const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChipButton(
                      label: requestWindowLabel(l10n, window),
                      selected: window == state.window,
                      onTap: day == null || state.isOpen(day, window)
                          ? () => cubit.selectWindow(window)
                          : null,
                    ),
                  ),
                ],
            ],
          ),
        ],
        if (state.showsErrors && !state.timeDone) ...[
          const SizedBox(height: 8),
          _Missing(l10n.newRequestTimeRequired(honorific)),
        ],
        const SizedBox(height: 14),
        _Summary(state: state),
      ],
    );
  }
}

/// "النهارده", "بكره السبت", then the weekday.
String _dayLabel(AppLocalizations l10n, DateTime day, int daysAhead) =>
    switch (daysAhead) {
      0 => l10n.today,
      1 => l10n.newRequestTomorrow(weekdayName(day)),
      _ => weekdayName(day),
    };

/// The request in a few lines, before it is sent.
class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final NewRequestState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final category = state.category;
    final issue = state.issue;
    final address = state.address;
    final day = state.day;
    final window = state.window;
    final technician = state.technician;
    final area = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(address?.areaId),
    );
    final photos = state.photos.length;
    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(14),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 15, height: 1.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.newRequestSummary,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (category != null && issue != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  requestTitle(l10n, issue, category: category.name),
                  if (photos > 0) l10n.newRequestSummaryPhotos(photos),
                ].join(' · '),
              ),
            ],
            if (address != null) ...[
              const SizedBox(height: 6),
              Text([address.label, ?area].join('، ')),
            ],
            if (day != null && window != null) ...[
              const SizedBox(height: 6),
              Text(
                '${_dayLabel(l10n, day, state.days.indexOf(day))}، '
                '${requestRangeLabel(l10n, window)}',
              ),
            ],
            if (technician != null) ...[
              const SizedBox(height: 6),
              Text(l10n.newRequestSummaryFirst(technician.name)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Next, or send on the last step, with how sending is going.
class _NextButton extends StatelessWidget {
  const _NextButton({required this.state});

  final NewRequestState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final honorific = context.watchHonorific();
    final progress = switch (state.status) {
      NewRequestStatus.uploading => l10n.newRequestUploading(
        state.uploaded + 1,
        state.photos.length,
      ),
      NewRequestStatus.sending => l10n.newRequestSending,
      _ => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              progress,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.appColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        BusyFilledButton(
          label: state.step == NewRequestStep.time
              ? l10n.newRequestSend(honorific)
              : l10n.newRequestNext,
          isBusy: state.isSending,
          onPressed: state.category == null
              ? null
              : context.read<NewRequestCubit>().next,
        ),
      ],
    );
  }
}

/// "طلبك اتبعت", and how many technicians got it.
class _SentStep extends StatelessWidget {
  const _SentStep({required this.sent, required this.category});

  final SentRequest sent;
  final String category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final sentTo = sent.sentTo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 66, 16, 18),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: colors.successSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 44, color: colors.success),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            l10n.newRequestSentTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          sentTo > 0
              ? '${l10n.newRequestSentTo(sentTo, category)} '
                    '${l10n.newRequestSentOffers(honorific)}'
              : l10n.newRequestSentToNobody(honorific, category),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.7, color: colors.inkMuted),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            // Back from the request goes home, not to this form.
            onPressed: () =>
                context.pushReplacement(AppRoutes.request(sent.id)),
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              padding: const EdgeInsets.all(12),
            ),
            child: Text(
              l10n.consumerHomeFollow(honorific),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackHomeButton extends StatelessWidget {
  const _BackHomeButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return FilledButton(
      onPressed: () => context.go(AppRoutes.consumerHome),
      style: FilledButton.styleFrom(
        backgroundColor: colors.inkSoft,
        foregroundColor: colors.ink,
      ),
      child: Text(AppLocalizations.of(context).newRequestBackHome),
    );
  }
}
