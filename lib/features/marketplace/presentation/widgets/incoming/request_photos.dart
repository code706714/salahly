import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The request's photos in a row; each opens full screen. A photo without
/// a link yet shows as a placeholder.
class RequestPhotos extends StatelessWidget {
  const RequestPhotos({required this.paths, required this.urls, super.key});

  final List<String> paths;

  /// Links by path.
  final Map<String, String> urls;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final path in paths)
          Semantics(
            image: true,
            label: l10n.incomingPhoto,
            child: _Tile(url: urls[path], size: _size),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final url = this.url;
    return Material(
      color: colors.border,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: url == null ? null : () => _open(context, url),
        child: SizedBox.square(
          dimension: size,
          child: url == null
              ? const _Placeholder()
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _Placeholder(),
                ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) => showDialog<void>(
    context: context,
    builder: (context) => _PhotoViewer(url: url),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 28,
        color: context.appColors.inkMuted,
      ),
    );
  }
}

/// One photo full screen, to zoom in.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Dialog.fullscreen(
      backgroundColor: colors.ink,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.jobPagePhotoClose,
                  color: colors.background,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: colors.onInkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
