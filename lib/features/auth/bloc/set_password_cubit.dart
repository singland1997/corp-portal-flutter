import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_failure.dart';
import '../data/session_repository.dart';

enum SetPasswordProblem { missingLink, tooShort, mismatch, invalidLink, tooManyAttempts, failed }

class SetPasswordState {
  const SetPasswordState({this.busy = false, this.done = false, this.problem});
  final bool busy, done;
  final SetPasswordProblem? problem;
}

/// First-time password setup from an admin-issued, single-use link.
class SetPasswordCubit extends Cubit<SetPasswordState> {
  SetPasswordCubit(this.repository, this.token) : super(const SetPasswordState());
  static const minimumCharacters = 12;
  final SessionRepository repository;
  final String token;

  SetPasswordProblem? validate(String password, String confirm) {
    if (token.isEmpty) return SetPasswordProblem.missingLink;
    if (password.runes.length < minimumCharacters || password.trim().isEmpty) return SetPasswordProblem.tooShort;
    if (password != confirm) return SetPasswordProblem.mismatch;
    return null;
  }

  Future<void> submit(String password, String confirm) async {
    if (state.busy || state.done) return;
    final problem = validate(password, confirm);
    if (problem != null) { emit(SetPasswordState(problem: problem)); return; }
    emit(const SetPasswordState(busy: true));
    try {
      await repository.setupPassword(token, password);
      if (!isClosed) emit(const SetPasswordState(done: true));
    } catch (error) {
      if (isClosed) return;
      final code = error is ApiFailure ? error.code : '';
      final status = error is ApiFailure ? error.status : null;
      emit(SetPasswordState(problem: switch (code) {
        'INVITE_INVALID' => SetPasswordProblem.invalidLink,
        'WEAK_PASSWORD' => SetPasswordProblem.tooShort,
        _ when status == 429 || code == 'RATE_LIMITED' => SetPasswordProblem.tooManyAttempts,
        _ => SetPasswordProblem.failed,
      }));
    }
  }
}
