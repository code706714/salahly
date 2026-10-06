import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/async/single_flight.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';

part 'my_requests_state.dart';

/// The consumer's requests, shared by the home screen and "طلباتي".
class MyRequestsCubit extends Cubit<MyRequestsState> {
  MyRequestsCubit(this._requests) : super(const MyRequestsState());

  final ConsumerRequestsRepository _requests;
  late final _fetch = SingleFlight(_fetchRequests);

  /// Fetches the list again. A failed refresh keeps the list shown.
  Future<void> load() => _fetch();

  Future<void> _fetchRequests() async {
    final result = await _requests.fetchRequests();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(MyRequestsState(status: MyRequestsStatus.ready, requests: value));
      case Err(:final failure):
        emit(
          MyRequestsState(
            status: state.status == MyRequestsStatus.ready
                ? MyRequestsStatus.ready
                : MyRequestsStatus.failed,
            requests: state.requests,
            failure: failure,
          ),
        );
    }
  }
}
