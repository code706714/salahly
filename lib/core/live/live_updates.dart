/// Tells the app the moment the server has something new for the person
/// signed in, so screens fetch again instead of waiting for the next poll.
abstract interface class LiveUpdates {
  /// Fires once for each notification the server records for this person:
  /// a request sent, an offer, a counter-price, a verification answer.
  Stream<void> get changes;
}
