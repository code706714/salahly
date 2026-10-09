import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/offer_thread.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_thread_cubit.dart';

void main() {
  final thread = OfferThread(
    state: const OfferTalk(
      offerId: 'offer-1',
      requestId: 'request-1',
      status: OfferStatus.sent,
      pricePiastres: 35000,
      awaiting: OfferTurn.consumer,
      countersLeft: 3,
      revisionsLeft: 2,
    ),
    events: [
      OfferEvent(
        kind: OfferEventKind.offer,
        actor: UserRole.technician,
        pricePiastres: 35000,
        createdAt: DateTime(2026, 10, 2, 20),
      ),
    ],
  );

  test('starts loading', () {
    expect(
      OfferThreadCubit(fetch: () async => Ok(thread)).state.status,
      OfferThreadStatus.loading,
    );
  });

  test('shows the thread', () async {
    final cubit = OfferThreadCubit(fetch: () async => Ok(thread));

    await cubit.load();

    expect(cubit.state.status, OfferThreadStatus.ready);
    expect(cubit.state.thread, thread);
    await cubit.close();
  });

  test('says when the offer is not theirs', () async {
    final cubit = OfferThreadCubit(fetch: () async => const Ok(null));

    await cubit.load();

    expect(cubit.state.status, OfferThreadStatus.missing);
    expect(cubit.state.thread, isNull);
    await cubit.close();
  });

  test('fails, then loads again on retry', () async {
    final answers = <Result<OfferThread?>>[
      const Err(NetworkFailure()),
      Ok(thread),
    ];
    final cubit = OfferThreadCubit(fetch: () async => answers.removeAt(0));

    await cubit.load();
    expect(cubit.state.status, OfferThreadStatus.failed);
    expect(cubit.state.failure, const NetworkFailure());

    final states = <OfferThreadStatus>[];
    final sub = cubit.stream.listen((state) => states.add(state.status));
    await cubit.load();
    await pumpEventQueue();
    await sub.cancel();

    expect(states, [OfferThreadStatus.loading, OfferThreadStatus.ready]);
    expect(cubit.state.thread, thread);
    expect(cubit.state.failure, isNull);
    await cubit.close();
  });
}
