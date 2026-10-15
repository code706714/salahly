import 'package:salahly/core/error/failure.dart';

/// The pack isn't on sale (anymore) for this person.
final class PackNotFoundFailure extends Failure {
  const PackNotFoundFailure();
}

/// The pack costs something else than what the person saw.
final class PriceChangedFailure extends Failure {
  const PriceChangedFailure();
}
