part of 'delete_account_cubit.dart';

enum DeleteAccountStatus { idle, deleting, deleted, failed }

final class DeleteAccountState extends Equatable {
  const DeleteAccountState({
    this.status = DeleteAccountStatus.idle,
    this.failure,
  });

  final DeleteAccountStatus status;

  /// Why the last try failed.
  final Failure? failure;

  @override
  List<Object?> get props => [status, failure];
}
