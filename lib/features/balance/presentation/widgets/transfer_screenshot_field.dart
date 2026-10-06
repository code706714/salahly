import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/dashed_rrect_border.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The transfer's screenshot: a dashed button to pick it, then a preview
/// with a way to pick another.
class TransferScreenshotField extends StatelessWidget {
  const TransferScreenshotField({
    required this.photoPicker,
    required this.honorific,
    required this.onPicked,
    this.path,
    super.key,
  });

  final PhotoPicker photoPicker;
  final String honorific;
  final ValueChanged<String> onPicked;

  /// The cleaned screenshot picked so far.
  final String? path;

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
      final picked = await photoPicker.pick(
        source: source,
        purpose: PhotoPurpose.transfer,
      );
      if (picked != null) onPicked(picked);
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
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final shot = path;
    if (shot != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.successSoft,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(shot),
                  width: 64,
                  height: 88,
                  fit: BoxFit.cover,
                  semanticLabel: l10n.buyUsesScreenshotPreview,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 64,
                    height: 88,
                    color: colors.border,
                    child: Icon(Icons.image_outlined, color: colors.inkMuted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.buyUsesScreenshotChosen,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.success,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _pick(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: colors.primaryPressed,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(l10n.buyUsesScreenshotChange),
              ),
            ],
          ),
        ),
      );
    }
    return DashedRRectBorder(
      color: colors.primary,
      radius: AppRadii.lg,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SizedBox(
            height: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 28,
                  color: colors.primaryPressed,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.buyUsesScreenshotAdd(honorific),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.primaryPressed,
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
