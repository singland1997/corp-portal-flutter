import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_failure.dart';
import '../data/session_models.dart';
import '../data/session_repository.dart';

sealed class AuthEvent {}
class AuthStarted extends AuthEvent {}
class LoginRequested extends AuthEvent {
  LoginRequested(this.email, this.password);
  final String email, password;
}
class LogoutRequested extends AuthEvent {}
class SessionRetryRequested extends AuthEvent {}
class CorporateSelected extends AuthEvent {
  CorporateSelected(this.id);
  final String id;
}
class _SessionChanged extends AuthEvent {}

class AuthState {
  const AuthState({this.user, this.corporateId, this.booting = false, this.busy = false, this.error, this.recoveryRequired = false});
  final SessionUser? user;
  final String? corporateId;
  final bool booting, busy;
  final bool recoveryRequired;
  final ApiFailure? error;
  bool get authenticated => user != null;
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this.repository) : super(const AuthState(booting: true)) {
    _subscription = repository.changes.listen((_) { if (!isClosed) add(_SessionChanged()); });
    on<AuthStarted>((event, emit) async {
      try { await repository.restore(); emit(_current()); }
      catch (error) { emit(_current(error: _failure(error))); }
    });
    on<LoginRequested>((event, emit) async {
      if (state.busy) return;
      emit(const AuthState(busy: true));
      try { await repository.login(event.email, event.password); emit(_current()); }
      catch (error) { emit(AuthState(error: _failure(error))); }
    });
    on<LogoutRequested>((event, emit) async {
      try { await repository.logout(); } catch (_) { /* Already signed out locally. */ }
      emit(const AuthState());
    });
    on<SessionRetryRequested>((event, emit) async {
      if (state.busy) return;
      emit(_current(busy: true));
      try { await repository.retryRefresh(); emit(_current()); }
      catch (error) { emit(_current(error: _failure(error))); }
    });
    on<CorporateSelected>((event, emit) async {
      await repository.selectCorporate(event.id);
      emit(_current());
    });
    on<_SessionChanged>((event, emit) => emit(_current()));
  }
  final SessionRepository repository;
  late final StreamSubscription<Session?> _subscription;
  AuthState _current({ApiFailure? error, bool busy = false}) => AuthState(
    user: repository.session?.user, corporateId: repository.corporateId,
    recoveryRequired: repository.refreshFailure != null,
    busy: busy, error: error ?? repository.refreshFailure,
  );
  ApiFailure _failure(Object error) => error is ApiFailure ? error : const ApiFailure(code: 'UNEXPECTED', message: 'Unable to sign in.');
  @override
  Future<void> close() async { await _subscription.cancel(); return super.close(); }
}
