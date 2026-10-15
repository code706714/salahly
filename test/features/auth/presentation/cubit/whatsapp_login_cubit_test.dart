import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/entities/whatsapp_login.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/auth/presentation/cubit/whatsapp_login_cubit.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockExternalApps extends Mock implements ExternalApps {}

void main() {
  final loginNumber = PhoneNumber.tryParse('1000000000')!;
  final challenge = WhatsappLoginChallenge(
    id: '11111111-2222-4333-8444-555555555555',
    code: 'AB3D5FGH',
    pollSecret: 'a' * 64,
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    whatsappNumber: loginNumber,
  );
  const tick = Duration(milliseconds: 10);

  late AuthRepository authRepository;
  late ExternalApps externalApps;
  late WhatsappLoginCubit cubit;

  String messageFor(String code) => 'كود: $code';

  setUpAll(() {
    registerFallbackValue(challenge);
    registerFallbackValue(loginNumber);
  });

  setUp(() {
    authRepository = _MockAuthRepository();
    externalApps = _MockExternalApps();
    cubit = WhatsappLoginCubit(
      authRepository: authRepository,
      externalApps: externalApps,
      pollInterval: tick,
    );
    when(
      () => authRepository.startWhatsappLogin(),
    ).thenAnswer((_) async => Ok(challenge));
    when(
      () => authRepository.whatsappLoginProgress(any()),
    ).thenAnswer((_) async => const Ok(WhatsappLoginProgress.pending));
    when(
      () => authRepository.completeWhatsappLogin(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => externalApps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() => cubit.close());

  Future<void> waitForPolls() => Future<void>.delayed(tick * 30);

  test('starts idle', () {
    expect(cubit.state, const WhatsappLoginState());
  });

  test('start asks for a code and opens WhatsApp with it', () async {
    await cubit.start(messageFor);

    expect(cubit.state.phase, WhatsappLoginPhase.waiting);
    expect(cubit.state.challenge, challenge);
    expect(cubit.state.couldNotOpenWhatsapp, isFalse);
    verify(
      () => externalApps.whatsApp(text: 'كود: AB3D5FGH', to: loginNumber),
    ).called(1);
  });

  test('start shows the busy state while it waits for the code', () async {
    final phases = <WhatsappLoginPhase>[];
    final subscription = cubit.stream.listen((s) => phases.add(s.phase));

    await cubit.start(messageFor);
    await subscription.cancel();

    expect(phases, [WhatsappLoginPhase.starting, WhatsappLoginPhase.waiting]);
  });

  test('start that fails goes back to idle with the reason', () async {
    when(() => authRepository.startWhatsappLogin()).thenAnswer(
      (_) async => const Err(WhatsappLoginUnavailableFailure()),
    );

    await cubit.start(messageFor);

    expect(
      cubit.state,
      const WhatsappLoginState(failure: WhatsappLoginUnavailableFailure()),
    );
    verifyNever(
      () => externalApps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    );
    verifyNever(() => authRepository.whatsappLoginProgress(any()));
  });

  test('start is ignored while one is already waiting', () async {
    await cubit.start(messageFor);
    await cubit.start(messageFor);

    verify(() => authRepository.startWhatsappLogin()).called(1);
  });

  test('says so when WhatsApp does not open, and still waits', () async {
    when(
      () => externalApps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => false);

    await cubit.start(messageFor);

    expect(cubit.state.phase, WhatsappLoginPhase.waiting);
    expect(cubit.state.couldNotOpenWhatsapp, isTrue);
  });

  test('the chat can be opened again', () async {
    await cubit.start(messageFor);
    await cubit.openWhatsapp();

    verify(
      () => externalApps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).called(2);
  });

  test('keeps asking until the message arrives, then signs in once', () async {
    var asked = 0;
    when(() => authRepository.whatsappLoginProgress(any())).thenAnswer((
      _,
    ) async {
      asked++;
      return Ok(
        asked < 3 ? WhatsappLoginProgress.pending : WhatsappLoginProgress.ready,
      );
    });

    await cubit.start(messageFor);
    await waitForPolls();

    expect(cubit.state.phase, WhatsappLoginPhase.signedIn);
    verify(() => authRepository.completeWhatsappLogin(challenge)).called(1);
    final askedWhenReady = asked;
    await waitForPolls();
    expect(asked, askedWhenReady, reason: 'it stops asking once ready');
  });

  test('a network blink while waiting does not end the wait', () async {
    var asked = 0;
    when(() => authRepository.whatsappLoginProgress(any())).thenAnswer((
      _,
    ) async {
      asked++;
      return asked == 1
          ? const Err(NetworkFailure())
          : const Ok(WhatsappLoginProgress.ready);
    });

    await cubit.start(messageFor);
    await waitForPolls();

    expect(cubit.state.phase, WhatsappLoginPhase.signedIn);
  });

  test('a code nobody sent in time expires', () async {
    when(() => authRepository.whatsappLoginProgress(any())).thenAnswer(
      (_) async => const Ok(WhatsappLoginProgress.expired),
    );

    await cubit.start(messageFor);
    await waitForPolls();

    expect(cubit.state.phase, WhatsappLoginPhase.expired);
    verifyNever(() => authRepository.completeWhatsappLogin(any()));
  });

  test(
    'expires by the clock even if the server keeps saying pending',
    () async {
      when(() => authRepository.startWhatsappLogin()).thenAnswer(
        (_) async => Ok(
          WhatsappLoginChallenge(
            id: challenge.id,
            code: challenge.code,
            pollSecret: challenge.pollSecret,
            expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
            whatsappNumber: loginNumber,
          ),
        ),
      );

      await cubit.start(messageFor);
      await waitForPolls();

      expect(cubit.state.phase, WhatsappLoginPhase.expired);
    },
  );

  test('after it expired the person can start again', () async {
    when(() => authRepository.whatsappLoginProgress(any())).thenAnswer(
      (_) async => const Ok(WhatsappLoginProgress.expired),
    );
    await cubit.start(messageFor);
    await waitForPolls();
    expect(cubit.state.phase, WhatsappLoginPhase.expired);

    await cubit.start(messageFor);

    verify(() => authRepository.startWhatsappLogin()).called(2);
    expect(cubit.state.phase, WhatsappLoginPhase.waiting);
  });

  test('a sign in that ran out at the last step expires', () async {
    when(() => authRepository.whatsappLoginProgress(any())).thenAnswer(
      (_) async => const Ok(WhatsappLoginProgress.ready),
    );
    when(() => authRepository.completeWhatsappLogin(any())).thenAnswer(
      (_) async => const Err(WhatsappLoginExpiredFailure()),
    );

    await cubit.start(messageFor);
    await waitForPolls();

    expect(cubit.state.phase, WhatsappLoginPhase.expired);
  });

  test('a sign in that fails at the last step shows why', () async {
    when(() => authRepository.whatsappLoginProgress(any())).thenAnswer(
      (_) async => const Ok(WhatsappLoginProgress.ready),
    );
    when(() => authRepository.completeWhatsappLogin(any())).thenAnswer(
      (_) async => const Err(NetworkFailure()),
    );

    await cubit.start(messageFor);
    await waitForPolls();

    expect(
      cubit.state,
      const WhatsappLoginState(failure: NetworkFailure()),
    );
  });

  test('cancel goes back to the start and stops asking', () async {
    await cubit.start(messageFor);
    cubit.cancel();

    expect(cubit.state, const WhatsappLoginState());
    clearInteractions(authRepository);
    await waitForPolls();
    verifyNever(() => authRepository.whatsappLoginProgress(any()));
  });

  test('closing stops asking', () async {
    await cubit.start(messageFor);
    await cubit.close();

    clearInteractions(authRepository);
    await waitForPolls();
    verifyNever(() => authRepository.whatsappLoginProgress(any()));
  });

  group('for one number only', () {
    WhatsappLoginCubit cubitFor(String phone) => WhatsappLoginCubit(
      authRepository: authRepository,
      externalApps: externalApps,
      onlyFor: PhoneNumber.tryParse(phone),
      pollInterval: tick,
    );

    setUp(() {
      when(
        () => authRepository.whatsappLoginProgress(any()),
      ).thenAnswer((_) async => const Ok(WhatsappLoginProgress.ready));
      when(() => authRepository.signOut()).thenAnswer((_) async {});
    });

    test('signs in when the message came from that number', () async {
      when(
        () => authRepository.currentUser,
      ).thenReturn(const AuthUser(id: 'u', phone: '201001234567'));
      final onlyCubit = cubitFor('1001234567');
      addTearDown(onlyCubit.close);

      await onlyCubit.start(messageFor);
      await waitForPolls();

      expect(onlyCubit.state.phase, WhatsappLoginPhase.signedIn);
      verifyNever(() => authRepository.signOut());
    });

    test('signs out again when another number sent it', () async {
      when(
        () => authRepository.currentUser,
      ).thenReturn(const AuthUser(id: 'u', phone: '201009999999'));
      final onlyCubit = cubitFor('1001234567');
      addTearDown(onlyCubit.close);

      await onlyCubit.start(messageFor);
      await waitForPolls();

      expect(
        onlyCubit.state,
        const WhatsappLoginState(failure: WhatsappLoginWrongNumberFailure()),
      );
      verify(() => authRepository.signOut()).called(1);
    });
  });
}
