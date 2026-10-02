import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/dashed_rrect_border.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// An empty dashed box that becomes the photo once one is picked.
class PhotoSlot extends StatelessWidget {
  const PhotoSlot({
    required this.label,
    required this.icon,
    required this.path,
    required this.purpose,
    required this.onPicked,
    required this.radius,
    this.width,
    this.height,
    this.hasError = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final String? path;
  final PhotoPurpose purpose;
  final ValueChanged<String> onPicked;
  final double radius;
  final double? width;
  final double? height;
  final bool hasError;

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picker = context.read<PhotoPicker>();
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
    try {
      final picked = await picker.pick(source: source, purpose: purpose);
      if (picked != null) onPicked(picked);
    } on PlatformException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.photoCameraDenied)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final picked = path;
    final shape = BorderRadius.circular(radius);
    final content = picked == null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.inkMuted),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.inkMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(picked), fit: BoxFit.cover),
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 16, color: colors.onPrimary),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: width,
        height: height,
        child: DashedRRectBorder(
          color: hasError
              ? colors.danger
              : picked == null
              ? colors.dashedBorder
              : Colors.transparent,
          radius: radius,
          child: Material(
            color: colors.surface,
            borderRadius: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: () => _pick(context), child: content),
          ),
        ),
      ),
    );
  }
}
