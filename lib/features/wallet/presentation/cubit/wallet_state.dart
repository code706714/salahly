part of 'wallet_cubit.dart';

enum WalletStatus { loading, ready, failed }

final class WalletState extends Equatable {
  const WalletState({this.status = WalletStatus.loading, this.wallet});

  final WalletStatus status;
  final Wallet? wallet;

  @override
  List<Object?> get props => [status, wallet];
}
