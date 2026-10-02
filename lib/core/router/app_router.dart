import 'package:go_router/go_router.dart';
import 'package:salahly/features/splash/presentation/pages/splash_page.dart';

GoRouter createRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
    ],
  );
}
