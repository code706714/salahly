import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';
import 'package:salahly/features/admin/domain/repositories/verification_repository.dart';

/// What the reviewer sees of one submission. Opening it is recorded in the
/// audit log, so it is loaded once per selection and not on every rebuild.
class VerificationDetailCubit extends Cubit<VerificationDetailState> {
  VerificationDetailCubit(this._repository, {required this.verificationId})
    : super(const VerificationDetailState());

  final VerificationRepository _repository;
  final String verificationId;

  Future<void> load() async {
    emit(const VerificationDetailState());
    final result = await _repository.fetchDetail(verificationId);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => VerificationDetailState(
        detail: value,
        isLoading: false,
      ),
      Err(:final failure) => VerificationDetailState(
        isLoading: false,
        failure: failure,
      ),
    });
  }
}

final class VerificationDetailState extends Equatable {
  const VerificationDetailState({
    this.detail,
    this.isLoading = true,
    this.failure,
  });

  final VerificationDetail? detail;
  final bool isLoading;
  final Failure? failure;

  @override
  List<Object?> get props => [detail, isLoading, failure];
}
