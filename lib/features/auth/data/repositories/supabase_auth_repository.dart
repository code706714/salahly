import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/entities/whatsapp_login.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, this._functions);

  static const _loginFunction = 'whatsapp-login';

  final supabase.GoTrueClient _auth;
  final supabase.FunctionsClient _functions;

  @override
  Stream<AuthUser?> get userChanges => _auth.onAuthStateChange
      .map((state) => _toAuthUser(state.session?.user))
      .distinct();

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Future<Result<WhatsappLoginChallenge>> startWhatsappLogin() async {
    try {
      final reply = await _callLogin({'action': 'start'});
      final number = PhoneNumber.tryParse(reply['whatsappNumber'] as String);
      if (number == null) return const Err(WhatsappLoginUnavailableFailure());
      return Ok(
        WhatsappLoginChallenge(
          id: reply['id'] as String,
          code: reply['code'] as String,
          pollSecret: reply['pollSecret'] as String,
          expiresAt: DateTime.parse(reply['expiresAt'] as String),
          whatsappNumber: number,
        ),
      );
    } on Object catch (error) {
      return Err(_loginFailureFrom(error));
    }
  }

  @override
  Future<Result<WhatsappLoginProgress>> whatsappLoginProgress(
    WhatsappLoginChallenge challenge,
  ) async {
    try {
      final reply = await _callLogin({
        'action': 'status',
        'id': challenge.id,
        'pollSecret': challenge.pollSecret,
      });
      return Ok(switch (reply['status']) {
        'pending' => WhatsappLoginProgress.pending,
        'ready' => WhatsappLoginProgress.ready,
        _ => WhatsappLoginProgress.expired,
      });
    } on Object catch (error) {
      return Err(_loginFailureFrom(error));
    }
  }

  @override
  Future<Result<void>> completeWhatsappLogin(
    WhatsappLoginChallenge challenge,
  ) async {
    try {
      final reply = await _callLogin({
        'action': 'complete',
        'id': challenge.id,
        'pollSecret': challenge.pollSecret,
      });
      await _auth.signInWithPassword(
        phone: reply['phone'] as String,
        password: reply['password'] as String,
      );
      return const Ok(null);
    } on Object catch (error) {
      return Err(_loginFailureFrom(error));
    }
  }

  Future<Map<String, dynamic>> _callLogin(Map<String, Object> body) async {
    final response = await _functions.invoke(_loginFunction, body: body);
    return response.data as Map<String, dynamic>;
  }

  /// Signs out on this phone straight away, even offline. Telling the server
  /// comes after and may fail; the session it keeps expires on its own.
  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on supabase.AuthException {
      // Already signed out here; only telling the server failed.
    }
  }

  static AuthUser? _toAuthUser(supabase.User? user) =>
      user == null ? null : AuthUser(id: user.id, phone: user.phone);

  static Failure _loginFailureFrom(Object error) {
    if (error is supabase.FunctionException) {
      return switch (error.status) {
        409 => const WhatsappLoginExpiredFailure(),
        503 => const WhatsappLoginUnavailableFailure(),
        _ => UnexpectedFailure(error),
      };
    }
    return commonFailureFrom(error);
  }
}
