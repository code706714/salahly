import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/router/session_redirect.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/account/presentation/pages/consumer_account_page.dart';
import 'package:salahly/features/account/presentation/pages/session_unavailable_page.dart';
import 'package:salahly/features/account/presentation/pages/technician_account_page.dart';
import 'package:salahly/features/auth/presentation/cubit/otp_cubit.dart';
import 'package:salahly/features/auth/presentation/cubit/phone_cubit.dart';
import 'package:salahly/features/auth/presentation/pages/otp_page.dart';
import 'package:salahly/features/auth/presentation/pages/phone_page.dart';
import 'package:salahly/features/customers/presentation/pages/customer_form_page.dart';
import 'package:salahly/features/customers/presentation/pages/customer_page.dart';
import 'package:salahly/features/customers/presentation/pages/customers_page.dart';
import 'package:salahly/features/home/presentation/pages/consumer_home_page.dart';
import 'package:salahly/features/home/presentation/pages/today_page.dart';
import 'package:salahly/features/home/presentation/widgets/consumer_scope.dart';
import 'package:salahly/features/home/presentation/widgets/consumer_shell.dart';
import 'package:salahly/features/home/presentation/widgets/technician_scope.dart';
import 'package:salahly/features/home/presentation/widgets/technician_shell.dart';
import 'package:salahly/features/jobs/presentation/pages/calendar_page.dart';
import 'package:salahly/features/jobs/presentation/pages/invoice_page.dart';
import 'package:salahly/features/jobs/presentation/pages/job_page.dart';
import 'package:salahly/features/jobs/presentation/pages/jobs_page.dart';
import 'package:salahly/features/jobs/presentation/pages/new_job_page.dart';
import 'package:salahly/features/jobs/presentation/pages/quote_page.dart';
import 'package:salahly/features/legal/presentation/pages/legal_page.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/pages/addresses_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/complaint_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/incoming_request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/incoming_requests_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/my_requests_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/new_request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/past_technicians_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/technician_profile_page.dart';
import 'package:salahly/features/money/presentation/pages/money_page.dart';
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
      _consumerRoutes(),
      _technicianRoutes(),
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

/// Everything under [AppRoutes.consumerHome], inside [ConsumerScope]:
/// three tabs that keep their place, and the screens pushed over them.
RouteBase _consumerRoutes() {
  String id(GoRouterState state) => state.pathParameters['id']!;

  return ShellRoute(
    builder: (context, state, child) => ConsumerScope(child: child),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ConsumerShell(navigationShell: navigationShell),
        branches: [
          _tab(AppRoutes.consumerHome, const ConsumerHomePage()),
          _tab(AppRoutes.consumerRequests, const MyRequestsPage()),
          _tab(AppRoutes.consumerAccount, const ConsumerAccountPage()),
        ],
      ),
      // Pushed over the tabs; listed before the request so "new" isn't
      // taken for a request id.
      GoRoute(
        path: AppRoutes.newRequest,
        builder: (context, state) => NewRequestPage(
          categoryId: state.uri.queryParameters['category'],
          technicianId: state.uri.queryParameters['technician'],
        ),
      ),
      GoRoute(
        path: '${AppRoutes.consumerRequests}/:id',
        builder: (context, state) => RequestPage(requestId: id(state)),
        routes: [
          GoRoute(
            path: 'complaint',
            builder: (context, state) => ComplaintPage(requestId: id(state)),
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.consumerTechnicians}/:id',
        builder: (context, state) => TechnicianProfilePage(
          technicianId: id(state),
          offer: switch (state.extra) {
            final RequestOffer offer => offer,
            _ => null,
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.consumerAddresses,
        builder: (context, state) => const AddressesPage(),
      ),
      GoRoute(
        path: AppRoutes.pastTechnicians,
        builder: (context, state) => const PastTechniciansPage(),
      ),
    ],
  );
}

StatefulShellBranch _tab(String path, Widget page) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => page)],
);

/// Everything under [AppRoutes.technicianHome], inside [TechnicianScope]:
/// four tabs that keep their place, and the screens pushed over them.
RouteBase _technicianRoutes() {
  String id(GoRouterState state) => state.pathParameters['id']!;

  return ShellRoute(
    builder: (context, state, child) => TechnicianScope(child: child),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TechnicianShell(navigationShell: navigationShell),
        branches: [
          _tab(AppRoutes.technicianHome, const TodayPage()),
          _tab(AppRoutes.technicianJobs, const JobsPage()),
          _tab(AppRoutes.technicianCustomers, const CustomersPage()),
          _tab(AppRoutes.technicianMoney, const MoneyPage()),
        ],
      ),
      // Pushed over the tabs. A tab's own path only matches exactly, so
      // these deeper paths fall through to here.
      GoRoute(
        path: AppRoutes.technicianAccount,
        builder: (context, state) => const TechnicianAccountPage(),
      ),
      GoRoute(
        path: AppRoutes.incomingRequests,
        builder: (context, state) => const IncomingRequestsPage(),
      ),
      GoRoute(
        path: '${AppRoutes.incomingRequests}/:id',
        builder: (context, state) => IncomingRequestPage(requestId: id(state)),
      ),
      GoRoute(
        path: AppRoutes.technicianCalendar,
        builder: (context, state) => const CalendarPage(),
      ),
      GoRoute(
        path: AppRoutes.newJob,
        builder: (context, state) => NewJobPage(
          customerId: state.uri.queryParameters['customer'],
          scheduledAt: DateTime.tryParse(
            state.uri.queryParameters['at'] ?? '',
          )?.toLocal(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.technicianJobs}/:id',
        builder: (context, state) => JobPage(jobId: id(state)),
        routes: [
          GoRoute(
            path: 'quote',
            builder: (context, state) => QuotePage(jobId: id(state)),
          ),
          GoRoute(
            path: 'invoice',
            builder: (context, state) => InvoicePage(jobId: id(state)),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.newCustomer,
        builder: (context, state) => CustomerFormPage(
          fromContacts: state.uri.queryParameters['from'] == 'contacts',
        ),
      ),
      GoRoute(
        path: '${AppRoutes.technicianCustomers}/:id',
        builder: (context, state) => CustomerPage(customerId: id(state)),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                CustomerFormPage(customerId: id(state)),
          ),
        ],
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
