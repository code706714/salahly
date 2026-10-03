import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the errors cubits report, e.g. from a failing stream. Installed
/// for the current test only.
class ErrorObserver extends BlocObserver {
  ErrorObserver._();

  /// Installs a new observer until the test ends.
  factory ErrorObserver.install() {
    final previous = Bloc.observer;
    final observer = ErrorObserver._();
    Bloc.observer = observer;
    addTearDown(() => Bloc.observer = previous);
    return observer;
  }

  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}
