import 'package:salahly/core/error/failure.dart';

/// The conversation doesn't exist for this person: no such request, or no
/// offer from that technician.
final class ChatUnavailableFailure extends Failure {
  const ChatUnavailableFailure();
}

/// The conversation is over: the offer is no longer standing, the request
/// closed, or the job's fourteen days have passed.
final class ChatClosedFailure extends Failure {
  const ChatClosedFailure();
}

/// The message holds a phone number, a link or another app's name.
final class ContactBlockedFailure extends Failure {
  const ContactBlockedFailure();
}
