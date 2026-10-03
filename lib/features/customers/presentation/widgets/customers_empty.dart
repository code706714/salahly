import 'package:flutter/material.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/customers/presentation/add_customer.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The customers tab before the first customer: why to add them, and the
/// two ways to.
class CustomersEmpty extends StatelessWidget {
  const CustomersEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 34),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.inkSoft,
              borderRadius: BorderRadius.circular(AppRadii.xxl),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 32,
              color: colors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.customersEmptyTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.customersEmptyBody,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
        ),
        const SizedBox(height: 22),
        _Way(
          icon: Icons.contacts_outlined,
          title: l10n.customersEmptyContacts,
          hint: l10n.customersEmptyContactsHint,
          onTap: () => addCustomer(context, AppRoutes.newCustomerFromContacts),
        ),
        const SizedBox(height: 16),
        _Way(
          icon: Icons.person_add_alt_outlined,
          title: l10n.customersEmptyAdd,
          hint: l10n.customersEmptyAddHint,
          onTap: () => addCustomer(context, AppRoutes.newCustomer),
        ),
      ],
    );
  }
}

class _Way extends StatelessWidget {
  const _Way({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hint,
                  style: TextStyle(fontSize: 14, color: colors.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.primary),
        ],
      ),
    );
  }
}
