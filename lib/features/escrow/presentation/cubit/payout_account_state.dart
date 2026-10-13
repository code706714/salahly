part of 'payout_account_cubit.dart';

enum PayoutAccountStatus { loading, failed, editing, saving, saved }

final class PayoutAccountState extends Equatable {
  const PayoutAccountState({
    this.status = PayoutAccountStatus.loading,
    this.method = TopupMethod.wallet,
    this.account = '',
    this.holder = '',
    this.failure,
  });

  final PayoutAccountStatus status;
  final TopupMethod method;

  /// The wallet number or InstaPay address, as typed.
  final String account;

  /// The name on the account, as typed.
  final String holder;
  final Failure? failure;

  /// The account as the server takes it, or null while it is not valid.
  String? get validAccount => normalizedSender(method, account);

  String? get validHolder {
    final name = holder.trim().replaceAll(RegExp(r'\s+'), ' ');
    return name.length >= 2 && name.length <= 80 ? name : null;
  }

  bool get canSave =>
      status == PayoutAccountStatus.editing &&
      validAccount != null &&
      validHolder != null;

  PayoutAccountState copyWith({
    PayoutAccountStatus? status,
    TopupMethod? method,
    String? account,
    String? holder,
    Failure? Function()? failure,
  }) {
    return PayoutAccountState(
      status: status ?? this.status,
      method: method ?? this.method,
      account: account ?? this.account,
      holder: holder ?? this.holder,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, method, account, holder, failure];
}
