import 'package:equatable/equatable.dart';

/// How a transfer is made.
enum TopupMethod { instapay, wallet }

/// Where the money for a pack is sent.
final class PaymentAccount extends Equatable {
  const PaymentAccount({
    required this.method,
    required this.account,
    required this.holderName,
  });

  final TopupMethod method;

  /// The InstaPay address or the wallet's mobile number.
  final String account;
  final String holderName;

  @override
  List<Object?> get props => [method, account, holderName];
}
