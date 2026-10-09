import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';

final _mobile = RegExp(r'^01[0125][0-9]{8}$');

/// A transfer someone says they made, as the team reviews it.
final class TopupReview extends Equatable {
  const TopupReview({
    required this.id,
    required this.role,
    required this.uses,
    required this.amountPiastres,
    required this.method,
    required this.senderAccount,
    required this.screenshotPath,
    required this.status,
    required this.createdAt,
    this.userId,
    this.name,
    this.accountPhone,
    this.rejectReason,
    this.reviewedAt,
  });

  final String id;

  /// Null when the person deleted their account.
  final String? userId;
  final String? name;

  /// The phone of the account in the app in local form (01...), to compare
  /// with [senderAccount]. Null when the account is gone.
  final String? accountPhone;
  final UserRole role;
  final int uses;
  final int amountPiastres;
  final TopupMethod method;

  /// The number or address the money was sent from.
  final String senderAccount;

  /// The screenshot in the `transfer-proofs` bucket.
  final String screenshotPath;
  final TopupStatus status;
  final String? rejectReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  /// Whether the money came from a mobile number other than the account's,
  /// which is allowed but worth a second look. An InstaPay address is not a
  /// number, so it never differs.
  bool get senderDiffersFromAccount =>
      accountPhone != null &&
      _mobile.hasMatch(senderAccount) &&
      accountPhone != senderAccount;

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    accountPhone,
    role,
    uses,
    amountPiastres,
    method,
    senderAccount,
    screenshotPath,
    status,
    rejectReason,
    createdAt,
    reviewedAt,
  ];
}

/// What the transfers list is narrowed to.
final class TopupFilter extends Equatable {
  const TopupFilter({this.status = TopupStatus.pending, this.role});

  /// The status to show; null for every one.
  final TopupStatus? status;

  /// Whose transfers to show; null for both sides.
  final UserRole? role;

  TopupFilter copyWith({
    TopupStatus? Function()? status,
    UserRole? Function()? role,
  }) {
    return TopupFilter(
      status: status != null ? status() : this.status,
      role: role != null ? role() : this.role,
    );
  }

  @override
  List<Object?> get props => [status, role];
}
