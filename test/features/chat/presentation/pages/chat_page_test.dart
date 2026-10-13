import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/live/live_updates.dart';
import 'package:salahly/features/chat/domain/entities/conversation.dart';
import 'package:salahly/features/chat/domain/failures/chat_failures.dart';
import 'package:salahly/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:salahly/features/chat/presentation/pages/chat_page.dart';

import '../../../../helpers/fake_live_updates.dart';
import '../../../../pump_app.dart';
import '../../chat_fixtures.dart';

void main() {
  late MockChatCubit cubit;
  late FakeLiveUpdates live;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  setUp(() {
    cubit = MockChatCubit();
    live = FakeLiveUpdates();
    when(() => cubit.refresh()).thenAnswer((_) async {});
    when(() => cubit.send(any())).thenAnswer((_) async => true);
  });

  void show(ChatState state) => when(() => cubit.state).thenReturn(state);

  Future<void> pumpView(
    WidgetTester tester, {
    void Function(String name)? onCall,
  }) => tester.pumpApp(
    ChatView(onCall: onCall),
    repositories: [RepositoryProvider<LiveUpdates>.value(value: live)],
    blocs: [BlocProvider<ChatCubit>.value(value: cubit)],
  );

  ChatState ready({
    bool isOpen = true,
    bool sending = false,
    List<ChatMessage>? messages,
  }) => ChatState(
    status: ChatLoadStatus.ready,
    conversation: testConversation(isOpen: isOpen, messages: messages),
    sending: sending,
  );

  testWidgets('calls the other side from the header', (tester) async {
    show(ready());
    String? called;
    await pumpView(tester, onCall: (name) => called = name);

    await tester.tap(find.byIcon(Icons.call_outlined));

    expect(called, 'محمود عبد الله');
  });

  testWidgets('has no call button in a closed chat or without a handler', (
    tester,
  ) async {
    show(ready(isOpen: false));
    await pumpView(tester, onCall: (_) {});
    expect(find.byIcon(Icons.call_outlined), findsNothing);

    show(ready());
    await pumpView(tester);
    expect(find.byIcon(Icons.call_outlined), findsNothing);
  });

  testWidgets('waits for the conversation', (tester) async {
    show(const ChatState());
    await pumpView(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n.chatTitle), findsOneWidget);
  });

  testWidgets('says when the conversation is not there', (tester) async {
    show(const ChatState(status: ChatLoadStatus.missing));
    await pumpView(tester);

    expect(find.text(l10n.marketplaceNotFound), findsOneWidget);
    expect(find.text(l10n.retry), findsNothing);
  });

  testWidgets('says when it could not be opened, and tries again', (
    tester,
  ) async {
    show(const ChatState(status: ChatLoadStatus.failed));
    await pumpView(tester);

    expect(find.text(l10n.chatLoadFailed), findsOneWidget);
    await tester.tap(find.text(l10n.retry));
    verify(() => cubit.refresh()).called(1);
  });

  testWidgets('shows the other side, the safety note and the messages', (
    tester,
  ) async {
    show(ready());
    await pumpView(tester);

    expect(find.text('محمود عبد الله'), findsOneWidget);
    expect(find.text(l10n.chatSafetyNote), findsOneWidget);
    expect(find.text('الجهاز بيفصل كتير'), findsOneWidget);
    expect(find.text('تمام، هجيلك بكره'), findsOneWidget);
    expect(find.text(l10n.chatEmpty), findsNothing);
    // The day is written once for the two messages of that day.
    expect(find.textContaining('السبت'), findsOneWidget);
  });

  testWidgets('puts my messages at the reading edge and theirs at the other', (
    tester,
  ) async {
    show(ready());
    await pumpView(tester);

    final mine = tester.getTopLeft(find.text('الجهاز بيفصل كتير')).dx;
    final theirs = tester.getTopLeft(find.text('تمام، هجيلك بكره')).dx;
    // Arabic reads from the right, so mine sit further right.
    expect(mine, greaterThan(theirs));
  });

  testWidgets('writes the day again when the day changes', (tester) async {
    show(
      ready(
        messages: [
          testMessage(createdAt: DateTime(2026, 10, 2, 22)),
          testMessage(
            id: 'm2',
            mine: false,
            body: 'صباح الخير',
            createdAt: DateTime(2026, 10, 3, 9),
          ),
        ],
      ),
    );
    await pumpView(tester);

    expect(find.textContaining('الجمعة'), findsOneWidget);
    expect(find.textContaining('السبت'), findsOneWidget);
  });

  testWidgets('invites the first message when there are none', (tester) async {
    show(ready(messages: const []));
    await pumpView(tester);

    expect(find.text(l10n.chatEmpty), findsOneWidget);
  });

  testWidgets('sends what is written and clears the box', (tester) async {
    show(ready());
    await pumpView(tester);

    await tester.enterText(find.byType(TextField), 'تمام كده');
    await tester.tap(find.byTooltip(l10n.chatSend));
    await tester.pump();

    verify(() => cubit.send('تمام كده')).called(1);
    expect(find.text('تمام كده'), findsNothing);
  });

  testWidgets('keeps the text when it was not sent', (tester) async {
    when(() => cubit.send(any())).thenAnswer((_) async => false);
    show(ready());
    await pumpView(tester);

    await tester.enterText(find.byType(TextField), 'كلمني 01012345678');
    await tester.tap(find.byTooltip(l10n.chatSend));
    await tester.pump();

    expect(find.text('كلمني 01012345678'), findsOneWidget);
  });

  testWidgets('cannot send again while a message is on its way', (
    tester,
  ) async {
    show(ready(sending: true));
    await pumpView(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == l10n.chatSend,
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('takes no message once the chat is closed', (tester) async {
    show(ready(isOpen: false));
    await pumpView(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.text(l10n.chatClosed), findsOneWidget);
    expect(find.text('الجهاز بيفصل كتير'), findsOneWidget);
  });

  testWidgets('says why a message was refused', (tester) async {
    whenListen(
      cubit,
      Stream.value(
        ready().copyWith(failure: () => const ContactBlockedFailure()),
      ),
      initialState: ready(),
    );
    await pumpView(tester);
    await tester.pump();

    expect(find.text(l10n.chatContactBlocked), findsOneWidget);
  });

  testWidgets('reads the chat again when the server has news', (tester) async {
    show(ready());
    await pumpView(tester);

    live.fire();

    verify(() => cubit.refresh()).called(1);
  });
}
