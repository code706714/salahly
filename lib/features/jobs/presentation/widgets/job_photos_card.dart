import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/dashed_rrect_border.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/presentation/cubit/job_details_cubit.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_card_label.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

const _tileRadius = 10.0;
const _gap = 6.0;

/// The photos of the work, before and after, with tiles to add more.
/// Reads [JobDetailsCubit] to keep and delete them.
class JobPhotosCard extends StatelessWidget {
  const JobPhotosCard({required this.details, super.key});

  final JobDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final after = details.photosOf(PhotoKind.after);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JobCardLabel(l10n.jobPagePhotos),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PhotoColumn(
                  title: l10n.jobPageBefore,
                  photos: details.photosOf(PhotoKind.before),
                  kind: PhotoKind.before,
                  addLabel: l10n.jobPageAddBefore,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: after.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ColumnTitle(l10n.jobPageAfter),
                          const SizedBox(height: _gap),
                          _AddTile(
                            kind: PhotoKind.after,
                            label: l10n.jobPageTakeAfter,
                            showLabel: true,
                          ),
                        ],
                      )
                    : _PhotoColumn(
                        title: l10n.jobPageAfter,
                        photos: after,
                        kind: PhotoKind.after,
                        addLabel: l10n.jobPageAddAfter,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColumnTitle extends StatelessWidget {
  const _ColumnTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
}

class _PhotoColumn extends StatelessWidget {
  const _PhotoColumn({
    required this.title,
    required this.photos,
    required this.kind,
    required this.addLabel,
  });

  final String title;
  final List<JobPhoto> photos;
  final PhotoKind kind;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColumnTitle(title),
        const SizedBox(height: _gap),
        LayoutBuilder(
          builder: (context, constraints) {
            // Two tiles a row, as large as the design's 72 when they fit.
            final size = min(
              72,
              (constraints.maxWidth - _gap) / 2,
            ).floorToDouble();
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (final photo in photos)
                  _PhotoTile(photo: photo, size: size),
                SizedBox.square(
                  dimension: size,
                  child: _AddTile(kind: kind, label: addLabel),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.size});

  final JobPhoto photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.jobPagePhoto,
      child: InkWell(
        borderRadius: BorderRadius.circular(_tileRadius),
        onTap: () => _open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_tileRadius),
          child: SizedBox.square(
            dimension: size,
            child: _PhotoImage(photo: photo, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<JobDetailsCubit>();
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => _PhotoViewer(photo: photo),
    );
    if (delete ?? false) await cubit.deletePhoto(photo.id);
  }
}

/// The photo's copy on this phone, or a placeholder for one only on the
/// server.
class _PhotoImage extends StatelessWidget {
  const _PhotoImage({required this.photo, required this.fit});

  final JobPhoto photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = photo.localPath;
    const placeholder = _Placeholder();
    if (path == null) return placeholder;
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ColoredBox(
      color: colors.border,
      child: Center(
        child: Text(
          AppLocalizations.of(context).jobPagePhoto,
          style: TextStyle(fontSize: 11, color: colors.inkMuted),
        ),
      ),
    );
  }
}

/// A dashed tile that picks a photo; [showLabel] writes [label] next to
/// the camera instead of only announcing it.
class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.kind,
    required this.label,
    this.showLabel = false,
  });

  final PhotoKind kind;
  final String label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final icon = Icon(
      Icons.photo_camera_outlined,
      size: 22,
      color: colors.inkMuted,
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: 72,
        child: DashedRRectBorder(
          color: colors.dashedBorder,
          radius: _tileRadius,
          child: InkWell(
            borderRadius: BorderRadius.circular(_tileRadius),
            onTap: () => _pick(context),
            child: Center(
              child: showLabel
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    )
                  : icon,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picker = context.read<PhotoPicker>();
    final cubit = context.read<JobDetailsCubit>();
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.photoTake),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.photoChoose),
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final String? path;
    try {
      path = await picker.pick(source: source, purpose: PhotoPurpose.job);
    } on PlatformException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoCameraDenied)));
      return;
    }
    if (path != null) await cubit.addPhoto(kind, path);
  }
}

/// A photo full screen, with a way to delete it. Pops true once the
/// technician confirms deleting it.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo});

  final JobPhoto photo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Dialog.fullscreen(
      backgroundColor: colors.ink,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: l10n.jobPagePhotoClose,
                    color: colors.background,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _confirmDelete(context),
                    tooltip: l10n.jobPagePhotoDelete,
                    color: colors.background,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                child: Center(
                  child: _PhotoImage(photo: photo, fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.jobPagePhotoDeleteTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.jobPageKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.jobPageDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) navigator.pop(true);
  }
}
