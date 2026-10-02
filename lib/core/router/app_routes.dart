/// Paths of every screen, so navigation never relies on string literals.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const otp = '/login/otp';
  static const welcome = '/welcome';
  static const onboarding = '/onboarding';
  static const consumerOnboarding = '/onboarding/consumer';
  static const technicianOnboarding = '/onboarding/technician';
  static const consumerHome = '/consumer';
  static const technicianHome = '/technician';
  static const sessionUnavailable = '/session-unavailable';
  static const legal = '/legal';
  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';
}
