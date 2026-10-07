import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';

/// A short-lived link to one private file, to show it as an image.
///
/// The link is held in memory only: it is never logged, stored or shown as
/// text, and a new one is made every time the image is asked for again.
class SignedImageCubit extends Cubit<SignedImageState> {
  SignedImageCubit(
    this._repository, {
    required this.bucket,
    required this.path,
  }) : super(const SignedImageState());

  final AdminFilesRepository _repository;
  final AdminBucket bucket;
  final String path;

  Future<void> load() async {
    emit(const SignedImageState());
    final result = await _repository.signedUrl(bucket, path);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => SignedImageState(url: value, isLoading: false),
      Err(:final failure) => SignedImageState(
        isLoading: false,
        failure: failure,
      ),
    });
  }
}

final class SignedImageState extends Equatable {
  const SignedImageState({this.url, this.isLoading = true, this.failure});

  /// Null until the link is made.
  final String? url;
  final bool isLoading;
  final Failure? failure;

  @override
  List<Object?> get props => [url, isLoading, failure];
}
