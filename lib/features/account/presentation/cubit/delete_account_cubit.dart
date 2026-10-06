import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/repositories/account_repository.dart';

part 'delete_account_state.dart';

/// Deletes the account. Signing out and wiping the phone follow on the
/// screen, once it has shown that the account is gone.
class DeleteAccountCubit extends Cubit<DeleteAccountState> {
  DeleteAccountCubit(this._account) : super(const DeleteAccountState());

  final AccountRepository _account;

  Future<void> delete() async {
    if (state.status == DeleteAccountStatus.deleting ||
        state.status == DeleteAccountStatus.deleted) {
      return;
    }
    emit(const DeleteAccountState(status: DeleteAccountStatus.deleting));
    final result = await _account.deleteAccount();
    if (isClosed) return;
    emit(switch (result) {
      Ok() => const DeleteAccountState(status: DeleteAccountStatus.deleted),
      Err(:final failure) => DeleteAccountState(
        status: DeleteAccountStatus.failed,
        failure: failure,
      ),
    });
  }
}
