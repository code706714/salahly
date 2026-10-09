import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';

/// The signed-in consumer, for consumer screens.
extension ConsumerSession on BuildContext {
  /// The consumer's profile, rebuilding this widget when it changes. Null
  /// briefly while signing out, before the redirect.
  ConsumerProfile? watchConsumer() => select<SessionCubit, ConsumerProfile?>(
    (cubit) => switch (cubit.state) {
      SessionReady(:final profile) => profile.consumer,
      _ => null,
    },
  );

  /// The consumer's honorific as the copy's `honorific` select takes it,
  /// rebuilding this widget when it changes.
  String watchHonorific() => watchConsumer()?.honorific.name ?? 'other';

  /// The same as [watchHonorific], for callbacks outside `build`.
  String readHonorific() => switch (read<SessionCubit>().state) {
    SessionReady(:final profile) => profile.consumer?.honorific.name ?? 'other',
    _ => 'other',
  };
}
