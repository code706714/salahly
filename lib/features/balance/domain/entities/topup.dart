import 'package:equatable/equatable.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';

/// Where a transfer stands.
enum TopupStatus { pending, approved, rejected }

/// A transfer the person said they made, as the server holds it: the uses
/// and the price are the pack's at that time.
final class Topup extends Equatable {
  const Topup({
    required this.id,
    required this.uses,
    required this.amountPiastres,
    required this.method,
    required this.status,
    required this.createdAt,
    this.rejectReason,
  });

  final String id;
  final int uses;
  final int amountPiastres;
  final TopupMethod method;
  final TopupStatus status;

  /// Why it was turned down, when it was.
  final String? rejectReason;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    uses,
    amountPiastres,
    method,
    status,
    rejectReason,
    createdAt,
  ];
}
