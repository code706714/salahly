import 'package:flutter/material.dart';
import 'package:salahly/core/text/arabic_search.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/normalize.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/presentation/widgets/pounds_field.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asks for a new quote line: typed out, or picked from the lines used
/// before ([suggestions], most used first), which narrow as the title is
/// typed. Returns the line, or null when dismissed.
Future<JobItemDraft?> showQuoteAddItemSheet(
  BuildContext context, {
  required List<ItemSuggestion> suggestions,
}) {
  return showModalBottomSheet<JobItemDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => QuoteAddItemSheet(suggestions: suggestions),
  );
}

class QuoteAddItemSheet extends StatefulWidget {
  const QuoteAddItemSheet({required this.suggestions, super.key});

  final List<ItemSuggestion> suggestions;

  @override
  State<QuoteAddItemSheet> createState() => _QuoteAddItemSheetState();
}

class _QuoteAddItemSheetState extends State<QuoteAddItemSheet> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_refresh);
    _price.addListener(_refresh);
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  String? get _titleText => normalizeText(_title.text);

  int? get _pricePiastres {
    final price = parsePounds(_price.text);
    if (price == null || price > JobItem.maxUnitPricePiastres) return null;
    return price;
  }

  List<ItemSuggestion> get _matches {
    final query = foldArabic(_title.text);
    if (query.isEmpty) return widget.suggestions;
    return [
      for (final suggestion in widget.suggestions)
        if (foldArabic(suggestion.title).contains(query)) suggestion,
    ];
  }

  void _add() {
    final title = _titleText;
    final price = _pricePiastres;
    if (title == null || price == null) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.of(context).pop(
      JobItemDraft(title: title, unitPricePiastres: price),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final matches = _matches;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.quoteAddItem,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: JobItem.maxTitleLength,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.quoteItemTitleLabel,
                hintText: l10n.quoteItemTitleHint,
                counterText: '',
                errorText: _showErrors && _titleText == null
                    ? l10n.quoteItemTitleRequired
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            PoundsField(
              controller: _price,
              labelText: l10n.quoteItemPriceLabel,
              onSubmitted: (_) => _add(),
              errorText: _showErrors && _pricePiastres == null
                  ? l10n.quoteItemPriceInvalid
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _add, child: Text(l10n.quoteItemAdd)),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.quoteSuggestions,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.inkMuted,
                ),
              ),
              const SizedBox(height: 4),
              for (final suggestion in matches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(suggestion.title),
                  trailing: Text(
                    l10n.pounds(formatPounds(suggestion.unitPricePiastres)),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(
                    JobItemDraft(
                      title: suggestion.title,
                      unitPricePiastres: suggestion.unitPricePiastres,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
