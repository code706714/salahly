import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "عندي مشكلة": opens the complaint screen for [requestId], and once the
/// complaint is sent says so and fetches the request again.
class ComplaintButton extends StatelessWidget {
  const ComplaintButton({required this.requestId, super.key});

  final String requestId;

  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<RequestCubit>();
    final sent = await context.push<bool>(
      AppRoutes.requestComplaint(requestId),
    );
    if (sent != true) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.complaintSent)));
    await cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextButton(
      onPressed: () => _open(context),
      style: TextButton.styleFrom(
        foregroundColor: colors.ink,
        padding: const EdgeInsets.all(10),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(AppLocalizations.of(context).complaintTitle),
    );
  }
}

/// Shown instead of [ComplaintButton] while a complaint is open.
class OpenComplaintNote extends StatelessWidget {
  const OpenComplaintNote({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.support_agent_rounded, size: 20, color: colors.inkMuted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            AppLocalizations.of(context).complaintOpen,
            style: TextStyle(fontSize: 14, height: 1.6, color: colors.inkMuted),
          ),
        ),
      ],
    );
  }
}
