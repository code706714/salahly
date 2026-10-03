import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "كاش", "إنستاباي", "فودافون كاش" or "تاني".
String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) =>
    switch (method) {
      PaymentMethod.cash => l10n.paymentMethodCash,
      PaymentMethod.instapay => l10n.paymentMethodInstapay,
      PaymentMethod.vodafoneCash => l10n.paymentMethodVodafoneCash,
      PaymentMethod.other => l10n.paymentMethodOther,
    };

/// An invoice number the way it is printed: 127 → "0127".
String invoiceNumberLabel(int number) => number.toString().padLeft(4, '0');
