part of 'buy_uses_cubit.dart';

enum BuyUsesStatus { loading, failed, editing, submitting, submitted }

final class BuyUsesState extends Equatable {
  const BuyUsesState({
    this.status = BuyUsesStatus.loading,
    this.packs = const [],
    this.accounts = const [],
    this.packId,
    this.method,
    this.sender = '',
    this.screenshot,
    this.failure,
  });

  final BuyUsesStatus status;
  final List<CreditPack> packs;
  final List<PaymentAccount> accounts;
  final String? packId;
  final TopupMethod? method;

  /// The account the money comes from, as typed.
  final String sender;

  /// The local path of the transfer's screenshot.
  final String? screenshot;

  /// Why loading or the last submit failed.
  final Failure? failure;

  CreditPack? get pack => packs.where((pack) => pack.id == packId).firstOrNull;

  /// The account to transfer to by the picked method.
  PaymentAccount? get account =>
      accounts.where((account) => account.method == method).firstOrNull;

  /// What one use costs alone: the pack of a single use, if one is on
  /// sale. Bigger packs show what they save against it.
  int? get singlePricePiastres =>
      packs.where((pack) => pack.uses == 1).firstOrNull?.pricePiastres;

  /// The sender as the server takes it, or null while it is not valid.
  String? get validSender {
    final method = this.method;
    return method == null ? null : normalizedSender(method, sender);
  }

  bool get canSubmit =>
      status == BuyUsesStatus.editing &&
      pack != null &&
      account != null &&
      validSender != null &&
      screenshot != null;

  BuyUsesState copyWith({
    BuyUsesStatus? status,
    List<CreditPack>? packs,
    List<PaymentAccount>? accounts,
    String? packId,
    TopupMethod? method,
    String? sender,
    String? Function()? screenshot,
    Failure? Function()? failure,
  }) {
    return BuyUsesState(
      status: status ?? this.status,
      packs: packs ?? this.packs,
      accounts: accounts ?? this.accounts,
      packId: packId ?? this.packId,
      method: method ?? this.method,
      sender: sender ?? this.sender,
      screenshot: screenshot != null ? screenshot() : this.screenshot,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    packs,
    accounts,
    packId,
    method,
    sender,
    screenshot,
    failure,
  ];
}
