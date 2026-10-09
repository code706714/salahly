import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/job_request_link.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';
import 'package:salahly/features/marketplace/presentation/widgets/arrival_button.dart';

import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

void main() {
  late MockTechnicianRequestsRepository requests;
  final sentAt = DateTime(2026, 10, 3, 11, 50);

  setUpAll(loadAppFonts);

  setUp(() {
    requests = MockTechnicianRequestsRepository();
    when(() => requests.fetchJobRequest('job-1')).thenAnswer(
      (_) async => const Ok(JobRequestLink(requestId: 'request-1')),
    );
  });

  Future<void> pump(WidgetTester tester, {bool isOffline = false}) async {
    await tester.pumpApp(
      Scaffold(
        body: ArrivalButton(jobId: 'job-1', isOffline: isOffline),
      ),
      repositories: [
        RepositoryProvider<TechnicianRequestsRepository>.value(
          value: requests,
        ),
      ],
    );
    await tester.pump();
  }

  Finder button() => find.byType(OutlinedButton);

  testWidgets('offers the button with a hint of what it does', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.arrivalButton), findsOneWidget);
    expect(find.text(l10n.arrivalHint), findsOneWidget);
    expect(find.text(l10n.arrivalSent), findsNothing);
    expect(tester.widget<OutlinedButton>(button()).onPressed, isNotNull);
  });

  testWidgets('tells the consumer, then shows it was sent and stops', (
    tester,
  ) async {
    when(
      () => requests.sendArriving('request-1'),
    ).thenAnswer((_) async => Ok(sentAt));
    await pump(tester);

    await tester.tap(button());
    await tester.pump();
    await tester.pump();

    verify(() => requests.sendArriving('request-1')).called(1);
    expect(find.text(l10n.arrivalSent), findsOneWidget);
    expect(find.text(l10n.arrivalButton), findsNothing);
    expect(find.text(l10n.arrivalHint), findsNothing);
    expect(tester.widget<OutlinedButton>(button()).onPressed, isNull);
  });

  testWidgets('shows progress and ignores a second tap while sending', (
    tester,
  ) async {
    final sending = Completer<Result<DateTime>>();
    when(
      () => requests.sendArriving('request-1'),
    ).thenAnswer((_) => sending.future);
    await pump(tester);

    await tester.tap(button());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<OutlinedButton>(button()).onPressed, isNull);
    verify(() => requests.sendArriving('request-1')).called(1);

    sending.complete(Ok(sentAt));
    await tester.pump();
    expect(find.text(l10n.arrivalSent), findsOneWidget);
  });

  testWidgets('is already marked sent when the consumer was told before', (
    tester,
  ) async {
    when(() => requests.fetchJobRequest('job-1')).thenAnswer(
      (_) async => Ok(
        JobRequestLink(requestId: 'request-1', arrivingSentAt: sentAt),
      ),
    );
    await pump(tester);

    expect(find.text(l10n.arrivalSent), findsOneWidget);
    expect(tester.widget<OutlinedButton>(button()).onPressed, isNull);
  });

  testWidgets('says it needs the internet and can be tried again', (
    tester,
  ) async {
    when(
      () => requests.sendArriving('request-1'),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await pump(tester);

    await tester.tap(button());
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.arrivalNeedsInternet), findsOneWidget);
    expect(find.text(l10n.arrivalSent), findsNothing);
    expect(tester.widget<OutlinedButton>(button()).onPressed, isNotNull);
  });

  testWidgets('warns before tapping while the phone is offline', (
    tester,
  ) async {
    await pump(tester, isOffline: true);

    expect(find.text(l10n.arrivalOffline), findsOneWidget);
    expect(find.text(l10n.arrivalHint), findsNothing);
  });

  testWidgets('explains a job the server does not have confirmed yet', (
    tester,
  ) async {
    when(
      () => requests.sendArriving('request-1'),
    ).thenAnswer((_) async => const Err(ArrivalNotReadyFailure()));
    await pump(tester);

    await tester.tap(button());
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.arrivalNotReady), findsOneWidget);
  });

  testWidgets('says the consumer was told often enough', (tester) async {
    when(
      () => requests.sendArriving('request-1'),
    ).thenAnswer((_) async => const Err(ArrivalLimitFailure()));
    await pump(tester);

    await tester.tap(button());
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.arrivalLimit), findsOneWidget);
  });
}
