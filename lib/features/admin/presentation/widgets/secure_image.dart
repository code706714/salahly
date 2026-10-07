import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/signed_image_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A private photo from storage, shown through a short-lived link made with
/// the admin's session. Tapping it opens it large. If it can not load it
/// says so and offers to try again, which makes a new link.
class SecureImage extends StatelessWidget {
  const SecureImage({
    required this.bucket,
    required this.path,
    required this.label,
    this.aspectRatio = 1.58,
    this.enlargeable = true,
    super.key,
  });

  final AdminBucket bucket;
  final String path;

  /// What the photo is, for screen readers and the large view.
  final String label;
  final double aspectRatio;

  /// Whether a tap opens it large. The large view itself turns this off.
  final bool enlargeable;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey((bucket, path)),
      create: (context) {
        final cubit = SignedImageCubit(
          context.read(),
          bucket: bucket,
          path: path,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: _Frame(
        label: label,
        aspectRatio: aspectRatio,
        onTap: enlargeable ? () => _enlarge(context) : null,
      ),
    );
  }

  void _enlarge(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: context.appColors.surface,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SecureImage(
                      bucket: bucket,
                      path: path,
                      label: label,
                      aspectRatio: 1.4,
                      enlargeable: false,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.adminClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.label,
    required this.aspectRatio,
    required this.onTap,
  });

  final String label;
  final double aspectRatio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final state = context.watch<SignedImageCubit>().state;
    final url = state.url;

    Widget message(String text, {Widget? action}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.inkMuted,
              ),
            ),
            ?action,
          ],
        ),
      ),
    );

    Widget retry() => TextButton(
      onPressed: context.read<SignedImageCubit>().load,
      child: Text(l10n.retry),
    );

    final content = switch ((state.isLoading, url)) {
      (true, _) => const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      (false, null) => message(l10n.adminImageFailed, action: retry()),
      (false, final String link) => Image.network(
        link,
        fit: BoxFit.contain,
        semanticLabel: label,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
        errorBuilder: (context, error, stackTrace) =>
            message(l10n.adminImageFailed, action: retry()),
      ),
    };

    return Semantics(
      label: label,
      image: true,
      button: onTap != null,
      child: Material(
        color: colors.border,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: url == null ? null : onTap,
          child: AspectRatio(aspectRatio: aspectRatio, child: content),
        ),
      ),
    );
  }
}
