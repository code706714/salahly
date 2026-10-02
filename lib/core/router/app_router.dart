import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/router/session_redirect.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/account/presentation/pages/session_unavailable_page.dart';
import 'package:salahly/features/auth/presentation/cubit/otp_cubit.dart';
import 'package:salahly/features/auth/presentation/cubit/phone_cubit.dart';
import 'package:salahly/features/auth/presentation/pages/otp_page.dart';
import 'package:salahly/features/auth/presentation/pages/phone_page.dart';
import 'package:salahly/features/home/presentation/pages/consumer_home_page.dart';
import 'package:salahly/features/home/presentation/pages/technician_home_page.dart';
import 'package:salahly/features/legal/presentation/pages/legal_page.dart';
import 'package:salahly/features/onboarding/domain/usecases/submit_technician_onboarding.dart';
import 'package:salahly/features/onboarding/presentation/cubit/consumer_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/pages/consumer_onboarding_page.dart';
import 'package:salahly/features/onboarding/presentation/pages/role_choice_page.dart';
import 'package:salahly/features/onboarding/presentation/pages/technician_onboarding_page.dart';
import 'package:salahly/features/splash/presentation/pages/splash_page.dart';

/// The app's routes. [refresh] must notify whenever [session] changes, so
/// redirects re-run; see [SessionRefresh].
GoRouter createRouter(SessionCubit session, {required Listenable refresh}) {
  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) =>
        sessionRedirect(session.state, state.uri.path),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => BlocProvider(
          create: (context) => PhoneCubit(context.read()),
          child: const PhonePage(),
        ),
        routes: [
          GoRoute(
            path: 'otp',
            redirect: (context, state) =>
                state.extra is OtpPageArgs ? null : AppRoutes.login,
            builder: (context, state) {
              final args = state.extra! as OtpPageArgs;
              return BlocProvider(
                create: (context) => OtpCubit(
                  authRepository: context.read(),
                  phone: args.phone,
                  channel: args.channel,
                ),
                child: const OtpPage(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const RoleChoicePage(),
      ),
      GoRoute(
        path: AppRoutes.consumerOnboarding,
        builder: (context, state) => BlocProvider(
          create: (context) {
            final cubit = ConsumerOnboardingCubit(
              catalogRepository: context.read(),
              onboardingRepository: context.read(),
              locationService: context.read(),
            );
            unawaited(cubit.load());
            return cubit;
          },
          child: const ConsumerOnboardingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.technicianOnboarding,
        builder: (context, state) => BlocProvider(
          create: (context) {
            final cubit = TechnicianOnboardingCubit(
              catalogRepository: context.read(),
              onboardingRepository: context.read(),
              locationService: context.read(),
              submitOnboarding: SubmitTechnicianOnboarding(context.read()),
            );
            unawaited(cubit.load());
            return cubit;
          },
          child: const TechnicianOnboardingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.consumerHome,
        builder: (context, state) => const ConsumerHomePage(),
      ),
      GoRoute(
        path: AppRoutes.technicianHome,
        builder: (context, state) => const TechnicianHomePage(),
      ),
      GoRoute(
        path: AppRoutes.sessionUnavailable,
        builder: (context, state) => const SessionUnavailablePage(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) =>
            const LegalPage(document: LegalDocument.terms),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) =>
            const LegalPage(document: LegalDocument.privacy),
      ),
    ],
  );
}

/// Notifies on every session change, to re-run the router's redirects.
class SessionRefresh extends ChangeNotifier {
  SessionRefresh(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
