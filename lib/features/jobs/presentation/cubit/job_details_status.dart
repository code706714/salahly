/// Where loading one job for its screens stands.
enum JobDetailsStatus {
  loading,
  ready,

  /// There was never such a job on this phone, e.g. an old link.
  missing,

  /// The job was there and has just been deleted.
  deleted,
}
