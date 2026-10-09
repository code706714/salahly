import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/admin/domain/repositories/requests_repository.dart';
import 'package:salahly/features/admin/domain/repositories/users_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/complaints_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/requests_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_action_listener.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_tabs.dart';
import 'package:salahly/features/admin/presentation/widgets/requests/complaints_list.dart';
import 'package:salahly/features/admin/presentation/widgets/requests/requests_list.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

enum _RequestsTab { requests, complaints }

/// Every request the customers made, and the complaints about the
/// technicians who did them.
class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = RequestsCubit(context.read());
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) {
            final cubit = ComplaintsCubit(context.read());
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) => ComplaintActionsCubit(
            requestsRepository: context.read<RequestsRepository>(),
            usersRepository: context.read<UsersRepository>(),
          ),
        ),
      ],
      child: const _RequestsView(),
    );
  }
}

class _RequestsView extends StatefulWidget {
  const _RequestsView();

  @override
  State<_RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends State<_RequestsView> {
  _RequestsTab _tab = _RequestsTab.requests;

  /// A complaint was closed or its technician suspended: the lists and the
  /// counts of the console are not what the server has any more.
  void _changed() {
    unawaited(context.read<ComplaintsCubit>().reload());
    unawaited(context.read<RequestsCubit>().reload());
    unawaited(context.read<OverviewCubit>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminActionListener<ComplaintActionsCubit>(
      onChanged: _changed,
      child: AdminPage(
        title: l10n.adminRequestsTitle,
        trailing: AdminTabs<_RequestsTab>(
          values: _RequestsTab.values,
          selected: _tab,
          labelOf: (tab) => switch (tab) {
            _RequestsTab.requests => l10n.adminRequestsTabRequests,
            _RequestsTab.complaints => l10n.adminRequestsTabComplaints,
          },
          onSelected: (tab) => setState(() => _tab = tab),
        ),
        child: switch (_tab) {
          _RequestsTab.requests => const RequestsList(),
          _RequestsTab.complaints => const ComplaintsList(),
        },
      ),
    );
  }
}
