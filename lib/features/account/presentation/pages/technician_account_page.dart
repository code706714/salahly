import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/account/presentation/widgets/sign_out_dialog.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technician's account: who they are, the legal texts and signing
/// out.
class TechnicianAccountPage extends StatelessWidget {
  const TechnicianAccountPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final session = context.read<SessionCubit>();
    final confirmed = await showSignOutDialog(
      context,
      sync: context.read<SyncCubit>(),
    );
    if (confirmed) await session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = context.select<SessionCubit, UserProfile?>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile,
        _ => null,
      },
    );
    return Scaffold(
      appBar: DetailHeader(title: l10n.myAccount),
      // Briefly null while signing out, before the redirect.
      body: profile == null
          ? null
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: 16),
                  _Group(
                    children: [
                      _Row(
                        label: l10n.balanceTitle,
                        onTap: () => context.push(AppRoutes.technicianBalance),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GroupLabel(l10n.accountHelp),
                  const SizedBox(height: 16),
                  _Group(
                    children: [
                      _Row(
                        label: l10n.legalTermsTitle,
                        onTap: () => context.push(AppRoutes.terms),
                      ),
                      _Row(
                        label: l10n.legalPrivacyTitle,
                        onTap: () => context.push(AppRoutes.privacy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Group(
                    children: [
                      _Row(
                        label: l10n.signOut,
                        opensPage: false,
                        onTap: () => _signOut(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final phone = PhoneNumber.tryParse(profile.phone);
    return Row(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.brass, width: 3),
          ),
          child: InitialsAvatar(name: profile.fullName, size: 62),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                phone == null ? profile.phone : '+20 ${phone.grouped}',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 14, color: colors.inkMuted),
              ),
              if (profile.technician?.verificationStatus case final status?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _VerificationPill(status),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerificationPill extends StatelessWidget {
  const _VerificationPill(this.status);

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (status) {
      VerificationStatus.approved => StatusPill(
        label: l10n.accountVerified,
        tone: PillTone.waiting,
        icon: Icons.verified_user_outlined,
      ),
      VerificationStatus.pending => StatusPill(
        label: l10n.techPendingTitle,
        tone: PillTone.waiting,
        icon: Icons.schedule_rounded,
      ),
      VerificationStatus.rejected => StatusPill(
        label: l10n.techRejectedTitle,
        tone: PillTone.attention,
        icon: Icons.error_outline_rounded,
      ),
    };
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.appColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// Rows in one card, divided by thin lines.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const Divider(),
            child,
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.onTap, this.opensPage = true});

  final String label;
  final VoidCallback onTap;

  /// Shows a chevron: the row opens another screen.
  final bool opensPage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, color: colors.ink),
                ),
              ),
              if (opensPage)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: colors.dashedBorder,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
