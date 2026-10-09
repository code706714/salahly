import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';

/// Pulling a technician screen down syncs the phone's records and fetches
/// the profile again, next to the live updates.
Future<void> refreshTechnician(BuildContext context) => Future.wait([
  context.read<SyncCubit>().syncNow(),
  context.read<SessionCubit>().refreshProfile(),
]);
