import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A moment of a request's progress: "السبت 12:00 الضهر".
String momentLabel(AppLocalizations l10n, DateTime time) =>
    '${weekdayName(time)} ${timeLabel(l10n, time)}';

/// A request's name for a consumer screen: "تكييف مش بيبرّد" once the
/// [categories] are fetched, and only the problem, "مش بيبرّد", until then.
String requestName(
  AppLocalizations l10n,
  CategoriesState categories, {
  required String categoryId,
  required RequestIssue issue,
}) {
  final category = categories.category(categoryId)?.name;
  return category == null
      ? requestIssueLabel(l10n, issue)
      : requestTitle(l10n, issue, category: category);
}

/// Request names that follow the categories.
extension RequestNames on BuildContext {
  /// [requestName], rebuilding the caller when the categories arrive.
  String watchRequestName(String categoryId, RequestIssue issue) => requestName(
    AppLocalizations.of(this),
    watch<CategoriesCubit>().state,
    categoryId: categoryId,
    issue: issue,
  );
}

/// How the consumer answered the technician's last price change.
extension PriceChangeAnswer on RequestDetails {
  /// The lines added or changed after the pick.
  List<PriceLine> get addedLines => [
    ...?job?.items.where((line) => line.addedLater),
  ];

  /// The answer to a price change the technician sent after the pick, or
  /// null when none was sent or it waits for an answer. Picking an offer
  /// accepts its price at the same moment, so only a later one counts.
  QuoteStatus? get priceChangeAnswer {
    final job = this.job;
    final sentAt = job?.quoteSentAt;
    final chosenAt = this.chosenAt;
    if (job == null || sentAt == null || chosenAt == null) return null;
    if (!sentAt.isAfter(chosenAt)) return null;
    return switch (job.quoteStatus) {
      QuoteStatus.accepted || QuoteStatus.declined => job.quoteStatus,
      _ => null,
    };
  }
}
