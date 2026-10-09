/// Paths of the console's screens.
abstract final class AdminRoutes {
  static const checking = '/';
  static const login = '/login';
  static const noAccess = '/no-access';
  static const unavailable = '/unavailable';
  static const overview = '/overview';
  static const verification = '/verification';
  static const transfers = '/transfers';
  static const requests = '/requests';
  static const users = '/users';
  static const settings = '/settings';
  static const audit = '/audit';

  /// The screens only a signed-in admin can open.
  static const List<String> console = [
    overview,
    verification,
    transfers,
    requests,
    users,
    settings,
    audit,
  ];
}
