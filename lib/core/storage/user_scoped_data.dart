/// Data the phone keeps for the signed-in user only.
abstract interface class UserScopedData {
  /// Makes the local data [userId]'s, deleting anyone else's first.
  Future<void> claimFor(String userId);

  /// Deletes everything, e.g. on sign-out.
  Future<void> clear();
}
