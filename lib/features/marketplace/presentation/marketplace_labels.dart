import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The problem as the request form lists it: "مش بيبرّد".
String requestIssueLabel(AppLocalizations l10n, RequestIssue issue) =>
    switch (issue) {
      RequestIssue.notCooling => l10n.requestIssueNotCooling,
      RequestIssue.leaking => l10n.requestIssueLeaking,
      RequestIssue.noisy => l10n.requestIssueNoisy,
      RequestIssue.needsCleaning => l10n.requestIssueNeedsCleaning,
      RequestIssue.installation => l10n.requestIssueInstallation,
      RequestIssue.other => l10n.requestIssueOther,
    };

/// A request's name in lists and headers: "تكييف مش بيبرّد", with the
/// category's name as [category].
String requestTitle(
  AppLocalizations l10n,
  RequestIssue issue, {
  required String category,
}) => switch (issue) {
  RequestIssue.notCooling => l10n.requestTitleNotCooling(category),
  RequestIssue.leaking => l10n.requestTitleLeaking(category),
  RequestIssue.noisy => l10n.requestTitleNoisy(category),
  RequestIssue.needsCleaning => l10n.requestTitleNeedsCleaning(category),
  RequestIssue.installation => l10n.requestTitleInstallation(category),
  RequestIssue.other => l10n.requestTitleOther(category),
};

/// The time window as a choice: "الضهر 12 لـ 3".
String requestWindowLabel(AppLocalizations l10n, RequestWindow window) =>
    switch (window) {
      RequestWindow.morning => l10n.requestWindowMorning,
      RequestWindow.noon => l10n.requestWindowNoon,
      RequestWindow.afternoon => l10n.requestWindowAfternoon,
      RequestWindow.evening => l10n.requestWindowEvening,
      RequestWindow.anyTime => l10n.requestWindowAnyTime,
    };

/// The time window after a day: "من 12 لـ 3 الضهر".
String requestRangeLabel(AppLocalizations l10n, RequestWindow window) =>
    switch (window) {
      RequestWindow.morning => l10n.requestRangeMorning,
      RequestWindow.noon => l10n.requestRangeNoon,
      RequestWindow.afternoon => l10n.requestRangeAfternoon,
      RequestWindow.evening => l10n.requestRangeEvening,
      RequestWindow.anyTime => l10n.requestRangeAnyTime,
    };
