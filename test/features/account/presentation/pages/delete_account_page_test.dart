import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/account/presentation/cubit/delete_account_cubit.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/account/presentation/pages/account_deleted_page.dart';
import 'package:salahly/features/account/presentation/pages/delete_account_page.dart';

import '../../../../helpers/balance_harness.dart';
import '../../../../helpers/consumer_app.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

class _MockDeleteAccountCubit extends MockCubit<DeleteAccountState>
    implements DeleteAccountCubit {}

void main() {
  late _MockDeleteAccountCubit cubit;
  late MockSessionCubit session;

  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
  });

  setUp(() {
    cubit = _MockDeleteAccountCubit();
    session = MockSessionCubit();
    when(() => cubit.state).thenReturn(const DeleteAccountState());
    when(cubit.delete).thenAnswer((_) async {});
    when(session.signOutDeleted).thenAnswer((_) async {});
  });

  Future<void> pumpView(
    WidgetTester tester,
    UserRole role, {
    SessionReady? signedIn,
  }) => tester.pumpApp(
    BlocProvider<DeleteAccountCubit>.value(
      value: cubit,
      child: DeleteAccountView(role: role),
    ),
    blocs: [
      BlocProvider<SessionCubit>.value(value: session..stubState(signedIn)),
    ],
    stubRoutes: [AppRoutes.accountDeleted],
  );

  Finder deleteButton() =>
      find.widgetWithText(FilledButton, 'امسح الحساب نهائي');

  group('a consumer', () {
    testWidgets('is told what goes, in her grammar, with her uses left', (
      tester,
    ) async {
      await pumpView(
        tester,
        UserRole.consumer,
        signedIn: consumerWithCredits(credits: 3),
      );

      expect(find.text('متأكدة إنك عايزة تمسحي حسابك؟'), findsOneWidget);
      expect(find.text('اللي هيتمسح:'), findsOneWidget);
      expect(find.text('بياناتك وعناوينك وصور طلباتك'), findsOneWidget);
      expect(find.text('رصيدك اللي فاضل (3 طلبات)'), findsOneWidget);
      expect(
        find.text('فاهمة إن المسح نهائي ومش هينفع أرجّع حسابي'),
        findsOneWidget,
      );
      expect(find.textContaining('اتعاملتي معاهم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is addressed as a man when he is one', (tester) async {
      await pumpView(
        tester,
        UserRole.consumer,
        signedIn: consumerWithCredits(honorific: Honorific.mr),
      );

      expect(find.text('متأكد إنك عايز تمسح حسابك؟'), findsOneWidget);
    });

    testWidgets('can only delete after confirming', (tester) async {
      await pumpView(
        tester,
        UserRole.consumer,
        signedIn: consumerWithCredits(),
      );

      expect(tester.widget<FilledButton>(deleteButton()).onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(deleteButton());

      verify(cubit.delete).called(1);
    });

    testWidgets('leaves with "no, keep it"', (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<SessionCubit>.value(
                  value: session..stubState(consumerWithCredits()),
                  child: BlocProvider<DeleteAccountCubit>.value(
                    value: cubit,
                    child: const DeleteAccountView(role: UserRole.consumer),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('لأ، خليه'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      verifyNever(cubit.delete);
    });

    testWidgets('shows a spinner and blocks everything while deleting', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const DeleteAccountState(status: DeleteAccountStatus.deleting),
      );

      await pumpView(
        tester,
        UserRole.consumer,
        signedIn: consumerWithCredits(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    });

    testWidgets('says why when a transfer is waiting', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          const DeleteAccountState(
            status: DeleteAccountStatus.failed,
            failure: PendingTransferFailure(),
          ),
        ),
        initialState: const DeleteAccountState(),
      );

      await pumpView(
        tester,
        UserRole.consumer,
        signedIn: consumerWithCredits(),
      );
      await tester.pump();

      expect(
        find.text(
          'عندك تحويل لسه بنراجعه. استني لحد ما يتراجع وبعدين امسحي الحساب.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says there is no network, in her words', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          const DeleteAccountState(
            status: DeleteAccountStatus.failed,
            failure: NetworkFailure(),
          ),
        ),
        initialState: const DeleteAccountState(),
      );

      await pumpView(
        tester,
        UserRole.consumer,
        signedIn: consumerWithCredits(),
      );
      await tester.pump();

      expect(find.text('مفيش نت. اتأكدي من النت وجرّبي تاني.'), findsOneWidget);
    });

    testWidgets('signs out and says goodbye once it is deleted', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.value(
          const DeleteAccountState(status: DeleteAccountStatus.deleted),
        ),
        initialState: const DeleteAccountState(),
      );

      await pumpView(
        tester,
        UserRole.consumer,
        signedIn: consumerWithCredits(),
      );
      await tester.pumpAndSettle();

      verify(session.signOutDeleted).called(1);
      expect(_goodbyeFor(tester), 'ms');
    });
  });

  group('a technician', () {
    testWidgets('is told what goes, in masculine copy', (tester) async {
      await pumpView(
        tester,
        UserRole.technician,
        signedIn: technicianSession(credits: 1),
      );

      expect(find.text('متأكد إنك عايز تمسح حسابك؟'), findsOneWidget);
      expect(find.text('بياناتك وصورك وعملاءك وشغلاناتك'), findsOneWidget);
      expect(find.text('رصيدك اللي فاضل (1 شغلانة مجانية)'), findsOneWidget);
      expect(find.text('صفحتك وتقييماتك، والعملاء مش هيلاقوك'), findsOneWidget);
      expect(find.textContaining('الفواتير وعروض الأسعار'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says a failure in the common words', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          const DeleteAccountState(
            status: DeleteAccountStatus.failed,
            failure: UnexpectedFailure(),
          ),
        ),
        initialState: const DeleteAccountState(),
      );

      await pumpView(
        tester,
        UserRole.technician,
        signedIn: technicianSession(),
      );
      await tester.pump();

      expect(find.text('حصلت مشكلة عندنا. جرّب تاني.'), findsOneWidget);
    });

    testWidgets('says goodbye in masculine copy', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          const DeleteAccountState(status: DeleteAccountStatus.deleted),
        ),
        initialState: const DeleteAccountState(),
      );

      await pumpView(
        tester,
        UserRole.technician,
        signedIn: technicianSession(),
      );
      await tester.pumpAndSettle();

      expect(_goodbyeFor(tester), 'other');
    });
  });

  group('the goodbye', () {
    testWidgets('thanks her and goes to sign-in', (tester) async {
      await tester.pumpApp(
        const AccountDeletedPage(honorific: 'ms'),
        stubRoutes: [AppRoutes.login],
      );

      expect(find.text('حسابك اتمسح'), findsOneWidget);
      expect(
        find.text(
          'شكراً إنك جرّبتي الأبلكيشن. لو حبيتي ترجعي، سجّلي برقمك من الأول.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('تمام'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.login), findsOneWidget);
    });

    testWidgets('speaks to him as a man', (tester) async {
      await tester.pumpApp(const AccountDeletedPage(honorific: 'other'));

      expect(
        find.text(
          'شكراً إنك جرّبت الأبلكيشن. لو حبيت ترجع، سجّل برقمك من الأول.',
        ),
        findsOneWidget,
      );
    });
  });
}

/// Whom the goodbye route was opened for.
String? _goodbyeFor(WidgetTester tester) => GoRouter.of(
  tester.element(find.text(AppRoutes.accountDeleted)),
).state.uri.queryParameters['honorific'];

extension on MockSessionCubit {
  void stubState(SessionReady? state) {
    if (state != null) when(() => this.state).thenReturn(state);
  }
}
