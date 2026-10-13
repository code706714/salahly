import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/live/live_updates.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/calls/domain/entities/call.dart';
import 'package:salahly/features/calls/domain/repositories/call_repository.dart';
import 'package:salahly/features/calls/presentation/widgets/incoming_call_scope.dart';

import '../../../../helpers/fake_live_updates.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

void main() {
  late MockCallRepository calls;
  late FakeLiveUpdates live;

  final ringing = IncomingCall(
    id: 'call-1',
    requestId: 'request-1',
    technicianId: 'tech-1',
    callerName: 'نورهان م.',
    createdAt: DateTime(2026, 10, 14, 10),
  );

  setUp(() {
    calls = MockCallRepository();
    live = FakeLiveUpdates();
    when(calls.pending).thenAnswer((_) async => const Ok(null));
  });

  Future<void> pumpScope(WidgetTester tester) => tester.pumpApp(
    const IncomingCallScope(role: UserRole.consumer, child: Text('home')),
    repositories: [
      RepositoryProvider<CallRepository>.value(value: calls),
      RepositoryProvider<LiveUpdates>.value(value: live),
    ],
    stubRoutes: const ['/consumer/call'],
  );

  testWidgets('stays put while nothing rings', (tester) async {
    await pumpScope(tester);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('opens the call screen when something rings', (tester) async {
    await pumpScope(tester);
    when(calls.pending).thenAnswer((_) async => Ok(ringing));

    live.fire();
    await tester.pumpAndSettle();

    expect(find.text('/consumer/call'), findsOneWidget);
  });

  testWidgets('opens each ringing call once', (tester) async {
    await pumpScope(tester);
    when(calls.pending).thenAnswer((_) async => Ok(ringing));
    live.fire();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('/consumer/call'))).pop();
    await tester.pumpAndSettle();

    live.fire();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('/consumer/call'), findsNothing);
  });
}
