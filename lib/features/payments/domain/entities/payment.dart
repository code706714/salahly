import 'package:equatable/equatable.dart';

/// Where an online payment stands, as the server holds it. Only the server
/// moves it: a redirect or a screen of ours never counts as payment.
enum PaymentStatus {
  /// Our order exists, the person has not opened the payment page yet.
  created,

  /// The payment page was opened or the provider is still deciding (a wallet
  /// payment waits for the person to approve it on their phone).
  pending,

  /// The provider confirmed the money reached us.
  succeeded,
  failed,
  cancelled,
  expired,

  /// The money went back to the person.
  refunded;

  /// Whether the payment may still succeed.
  bool get isOpen => this == created || this == pending;
}

/// A payment order of the signed-in person.
final class PaymentOrder extends Equatable {
  const PaymentOrder({required this.id, required this.status});

  final String id;
  final PaymentStatus status;

  @override
  List<Object?> get props => [id, status];
}

/// A payment started on the server: the page to pay on.
final class PaymentCheckout extends Equatable {
  const PaymentCheckout({
    required this.orderId,
    required this.url,
    required this.amountPiastres,
  });

  final String orderId;
  final Uri url;

  /// What the server will charge, decided by the server.
  final int amountPiastres;

  @override
  List<Object?> get props => [orderId, url, amountPiastres];
}
