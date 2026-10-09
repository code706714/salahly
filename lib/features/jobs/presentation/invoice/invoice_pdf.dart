import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_labels.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A job's invoice as an A4 page in Arabic, right to left, set in the
/// app's own font.
class InvoicePdf {
  const InvoicePdf({this._bundle});

  final AssetBundle? _bundle;

  static const _regularFont = 'assets/fonts/IBMPlexSansArabic-Regular.ttf';
  static const _boldFont = 'assets/fonts/IBMPlexSansArabic-Bold.ttf';

  /// The PDF file's bytes. [place] is where the work was, when known.
  Future<Uint8List> build(
    AppLocalizations l10n, {
    required JobDetails details,
    required String technicianName,
    required PhoneNumber? technicianPhone,
    required DateTime issuedOn,
    String? place,
  }) async {
    final bundle = _bundle ?? rootBundle;
    final regular = pw.Font.ttf(await bundle.load(_regularFont));
    final bold = pw.Font.ttf(await bundle.load(_boldFont));
    final number = details.job.invoiceNumber;
    final title = number == null
        ? l10n.invoiceTitleUnnumbered
        : l10n.invoiceTitle(invoiceNumberLabel(number));
    final content = _InvoiceContent(
      l10n,
      details: details,
      title: title,
      technicianName: technicianName,
      technicianPhone: technicianPhone,
      issuedOn: issuedOn,
      place: place,
    );
    final document = pw.Document(title: title, author: technicianName)
      ..addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
          build: content.build,
        ),
      );
    return document.save();
  }
}

PdfColor _pdf(Color color) => PdfColor.fromInt(color.toARGB32());

class _InvoiceContent {
  _InvoiceContent(
    this.l10n, {
    required this.details,
    required this.title,
    required this.technicianName,
    required this.technicianPhone,
    required this.issuedOn,
    required this.place,
  });

  final AppLocalizations l10n;
  final JobDetails details;
  final String title;
  final String technicianName;
  final PhoneNumber? technicianPhone;
  final DateTime issuedOn;
  final String? place;

  static const AppColors _colors = AppColors.light;
  final PdfColor _ink = _pdf(_colors.ink);
  final PdfColor _muted = _pdf(_colors.inkMuted);
  final PdfColor _divider = _pdf(_colors.divider);

  String _pounds(int piastres) => l10n.pounds(formatPounds(piastres));

  List<pw.Widget> build(pw.Context context) {
    final balance = details.balancePiastres;
    return [
      _header(),
      pw.SizedBox(height: 24),
      _customer(),
      pw.SizedBox(height: 24),
      _row(
        [
          l10n.invoicePdfItem,
          l10n.invoicePdfQuantity,
          l10n.invoicePdfUnitPrice,
          l10n.invoicePdfAmount,
        ],
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _muted,
        ),
        background: _pdf(_colors.background),
      ),
      for (final item in details.items)
        _row([
          item.title,
          '${item.quantity}',
          formatPounds(item.unitPricePiastres),
          formatPounds(item.totalPiastres),
        ]),
      pw.SizedBox(height: 16),
      _total(
        l10n.invoiceTotal,
        details.totalPiastres,
        style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
      ),
      _total(
        l10n.invoicePaid,
        details.paidPiastres,
        style: pw.TextStyle(fontSize: 12, color: _pdf(_colors.success)),
      ),
      _total(
        l10n.invoiceBalance,
        balance,
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: _pdf(balance > 0 ? _colors.danger : _colors.success),
        ),
      ),
      if (details.payments.isNotEmpty) ...[
        pw.SizedBox(height: 24),
        pw.Text(
          l10n.invoicePayments,
          style: pw.TextStyle(fontSize: 11, color: _muted),
        ),
        pw.SizedBox(height: 4),
        for (final payment in details.payments)
          _total(
            l10n.invoicePaymentLine(
              paymentMethodLabel(l10n, payment.method),
              weekdayDate(payment.receivedAt),
            ),
            payment.amountPiastres,
            style: const pw.TextStyle(fontSize: 12),
          ),
      ],
      pw.SizedBox(height: 32),
      pw.Text(l10n.invoiceThanks, style: pw.TextStyle(color: _muted)),
    ];
  }

  pw.Widget _header() {
    final light = _pdf(_colors.background);
    final faint = _pdf(_colors.onInkMuted);
    final phone = technicianPhone;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: pw.BoxDecoration(
        color: _ink,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  l10n.invoiceSignature(technicianName),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: light,
                  ),
                ),
                if (phone != null)
                  pw.Text(
                    phone.local,
                    textDirection: pw.TextDirection.ltr,
                    style: pw.TextStyle(fontSize: 12, color: faint),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: light,
                ),
              ),
              pw.Text(
                DateFormat('d MMMM y', 'ar').format(issuedOn),
                style: pw.TextStyle(fontSize: 12, color: faint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _customer() {
    final customer = details.customer;
    final phone = customer.phone;
    final place = this.place;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          l10n.invoicePdfCustomer,
          style: pw.TextStyle(fontSize: 11, color: _muted),
        ),
        pw.Text(
          customer.name,
          style: const pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (phone != null)
          pw.Text(
            phone.local,
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(fontSize: 12, color: _muted),
          ),
        if (place != null)
          pw.Text(place, style: pw.TextStyle(fontSize: 12, color: _muted)),
        pw.SizedBox(height: 8),
        pw.Text(
          jobTitle(l10n, details.job),
          style: pw.TextStyle(fontSize: 12, color: _ink),
        ),
      ],
    );
  }

  /// A line of the items table: the item, then its numbers.
  pw.Widget _row(
    List<String> cells, {
    pw.TextStyle style = const pw.TextStyle(fontSize: 12),
    PdfColor? background,
  }) {
    const flexes = [5, 1, 2, 2];
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: pw.BoxDecoration(
        color: background,
        border: pw.Border(bottom: pw.BorderSide(color: _divider)),
      ),
      child: pw.Row(
        children: [
          for (final (index, cell) in cells.indexed)
            pw.Expanded(
              flex: flexes[index],
              child: pw.Text(
                cell,
                style: style,
                textAlign: index == 0 ? pw.TextAlign.start : pw.TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _total(
    String label,
    int piastres, {
    required pw.TextStyle style,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(_pounds(piastres), style: style),
        ],
      ),
    );
  }
}
