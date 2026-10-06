import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';

/// The signed-in user's balance.
extension UsesLeft on BuildContext {
  /// The uses [role] has left, rebuilding this widget when they change.
  int watchUsesLeft(UserRole role) => select<SessionCubit, int>(
    (cubit) => switch (cubit.state) {
      SessionReady(:final profile) => switch (role) {
        UserRole.consumer => profile.consumer?.requestCredits ?? 0,
        UserRole.technician => profile.technician?.jobCredits ?? 0,
      },
      _ => 0,
    },
  );
}
