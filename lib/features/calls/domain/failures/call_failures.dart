import 'package:salahly/core/error/failure.dart';

/// There is no call to make or take: the chat is closed, or the call is over.
final class CallUnavailableFailure extends Failure {
  const CallUnavailableFailure();
}

/// The person is already on a call.
final class CallInProgressFailure extends Failure {
  const CallInProgressFailure();
}

/// The other side is on a call.
final class CalleeBusyFailure extends Failure {
  const CalleeBusyFailure();
}
