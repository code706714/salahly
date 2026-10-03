import 'package:flutter/material.dart';
import 'package:salahly/core/text/arabic_search.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Lets the technician search their customers by name or number and pick
/// one. Resolves to null if dismissed.
Future<Customer?> showCustomerPicker(
  BuildContext context, {
  required List<Customer> customers,
}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _CustomerPicker(customers: customers),
  );
}

/// Whether [customer] matches [query]: part of the name, ignoring the
/// Arabic letter variants people mix up, or digits of the phone.
bool customerMatches(Customer customer, String query) {
  final words = foldArabic(query).toLowerCase();
  if (words.isEmpty) return true;
  if (foldArabic(customer.name).toLowerCase().contains(words)) return true;
  final digits = digitsOnly(query);
  final phone = customer.phone;
  return digits.isNotEmpty &&
      phone != null &&
      ('0${phone.nationalNumber}'.contains(digits) ||
          phone.international.contains(digits));
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker({required this.customers});

  final List<Customer> customers;

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final matches = [
      for (final customer in widget.customers)
        if (customerMatches(customer, _query)) customer,
    ];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                l10n.newJobCustomerSheetTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.newJobCustomerSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        l10n.newJobNoCustomerMatch,
                        style: TextStyle(color: colors.inkMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final customer = matches[index];
                        final phone = customer.phone;
                        return ListTile(
                          minTileHeight: 64,
                          leading: InitialsAvatar(
                            name: customer.name,
                            size: 40,
                          ),
                          title: Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: phone == null
                              ? null
                              : Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    phone.local,
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(color: colors.inkMuted),
                                  ),
                                ),
                          onTap: () => Navigator.of(context).pop(customer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
