import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';

import '../../../pump_app.dart';

void main() {
  test('names every problem, title and window', () {
    for (final issue in RequestIssue.values) {
      expect(requestIssueLabel(l10n, issue), isNotEmpty);
    }
    expect(
      [
        RequestIssue.notCooling,
        RequestIssue.leaking,
        RequestIssue.noisy,
        RequestIssue.needsCleaning,
        RequestIssue.installation,
        RequestIssue.other,
      ].map((issue) => requestTitle(l10n, issue, category: 'تكييف')),
      [
        'تكييف مش بيبرّد',
        'تكييف بينقّط مية',
        'تكييف صوته عالي',
        'تنظيف تكييف',
        'تركيب تكييف جديد',
        'مشكلة في التكييف',
      ],
    );
    expect(requestWindowLabel(l10n, RequestWindow.noon), 'الضهر 12 لـ 3');
    expect(requestRangeLabel(l10n, RequestWindow.noon), 'من 12 لـ 3 الضهر');
    expect(
      RequestWindow.values.map((window) => requestRangeLabel(l10n, window)),
      hasLength(RequestWindow.values.toSet().length),
    );
  });
}
