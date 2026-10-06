import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/account/presentation/widgets/sign_out_dialog.dart';
import 'package:salahly/features/marketplace/presentation/cubit/addresses_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The "حسابي" tab: the profile, requests left, addresses and help.
class ConsumerAccountPage extends StatelessWidget {
  const ConsumerAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = AddressesCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const ConsumerAccountView(),
    );
  }
}

class ConsumerAccountView extends StatelessWidget {
  const ConsumerAccountView({super.key});

  Future<void> _openAddresses(BuildContext context) async {
    final addresses = context.read<AddressesCubit>();
    await context.push(AppRoutes.consumerAddresses);
    await addresses.load();
  }

  Future<void> _signOut(BuildContext context) async {
    final session = context.read<SessionCubit>();
    final confirmed = await showSignOutDialog(
      context,
      honorific: context.readHonorific(),
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
    final consumer = profile?.consumer;
    // Briefly null while signing out, before the redirect.
    if (profile == null || consumer == null) return const Scaffold();
    final honorific = context.watchHonorific();
    final addresses = context.select<AddressesCubit, int?>(
      (cubit) => cubit.state.status == AddressesStatus.ready
          ? cubit.state.addresses.length
          : null,
    );

    return BlocListener<MyRequestsCubit, MyRequestsState>(
      // A new request may have added an address.
      listenWhen: (previous, current) => previous.requests != current.requests,
      listener: (context, state) =>
          unawaited(context.read<AddressesCubit>().load()),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _ProfileHeader(profile: profile),
              const SizedBox(height: 16),
              _CreditsCard(credits: consumer.requestCredits),
              const SizedBox(height: 16),
              _GroupLabel(l10n.consumerAccountMyData),
              const SizedBox(height: 16),
              _Group(
                children: [
                  _Row(
                    icon: Icons.location_on_outlined,
                    label: l10n.addressesTitle,
                    count: addresses,
                    onTap: () => _openAddresses(context),
                  ),
                  _Row(
                    icon: Icons.format_list_bulleted_rounded,
                    label: l10n.pastTechniciansTitle,
                    onTap: () => context.push(AppRoutes.pastTechnicians),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _GroupLabel(l10n.accountHelp),
              const SizedBox(height: 16),
              _Group(
                children: [
                  _Row(
                    icon: Icons.flag_outlined,
                    label: l10n.consumerAccountRequestProblem,
                    onTap: () => context.go(AppRoutes.consumerRequests),
                  ),
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
                    label: l10n.consumerAccountSignOut(honorific),
                    opensPage: false,
                    onTap: () => _signOut(context),
                  ),
                ],
              ),
            ],
          ),
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
        InitialsAvatar(
          name: profile.fullName,
          size: 64,
          color: colors.primarySoft,
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
              Text(
                phone == null ? profile.phone : '+20 ${phone.grouped}',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 14, color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "رصيد الطلبات · 4 طلبات" on the dark card.
class _CreditsCard extends StatelessWidget {
  const _CreditsCard({required this.credits});

  final int credits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.consumerAccountCreditsTitle,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colors.onInkMuted,
            ),
          ),
          Text(
            l10n.consumerAccountCredits(credits),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: colors.background,
            ),
          ),
        ],
      ),
    );
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
  const _Row({
    required this.label,
    required this.onTap,
    this.icon,
    this.count,
    this.opensPage = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// How many there are, shown before the chevron.
  final int? count;

  /// Shows a chevron: the row opens another screen.
  final bool opensPage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final icon = this.icon;
    final count = this.count;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: colors.ink),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, color: colors.ink),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 12),
                Text(
                  '$count',
                  style: TextStyle(fontSize: 14, color: colors.inkMuted),
                ),
              ],
              if (opensPage) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: colors.dashedBorder,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
