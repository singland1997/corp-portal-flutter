import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_failure.dart';
import '../data/user_models.dart';
import '../data/users_repository.dart';

sealed class UserEditorEvent {}

class UserEditorOpened extends UserEditorEvent {}

class UserDraftChanged extends UserEditorEvent {
  UserDraftChanged(this.draft);
  final UserDraft draft;
}

class UserSaveRequested extends UserEditorEvent {}

class UserInviteRequested extends UserEditorEvent {}

class UserValidationFailure {
  const UserValidationFailure(this.code);
  final String code;
}

class UserEditorState {
  const UserEditorState({
    required this.draft,
    this.assignments = const [],
    this.loading = true,
    this.saving = false,
    this.assignmentsLoaded = false,
    this.saved = false,
    this.invite,
    this.error,
  });
  final UserDraft draft;
  final List<SalesAssignment> assignments;
  final bool loading;
  final bool saving;
  final bool assignmentsLoaded;
  final bool saved;
  final UserInvite? invite;
  final Object? error;
  bool get busy => loading || saving;

  UserEditorState copyWith({
    UserDraft? draft,
    List<SalesAssignment>? assignments,
    bool? loading,
    bool? saving,
    bool? assignmentsLoaded,
    bool? saved,
    UserInvite? invite,
    Object? error,
  }) => UserEditorState(
    draft: draft ?? this.draft,
    assignments: assignments ?? this.assignments,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    assignmentsLoaded: assignmentsLoaded ?? this.assignmentsLoaded,
    saved: saved ?? this.saved,
    invite: invite ?? this.invite,
    error: error,
  );
}

/// UI restrictions are advisory; the API enforces role and unique assignment rules.
class UserEditorBloc extends Bloc<UserEditorEvent, UserEditorState> {
  UserEditorBloc({
    required this.repository,
    required this.catalog,
    this.user,
    String? selectedCorporate,
  }) : super(UserEditorState(
    draft: user == null
        ? UserDraft(corporateId: selectedCorporate)
        : UserDraft.fromUser(user),
  )) {
    on<UserEditorOpened>(_load);
    on<UserDraftChanged>((event, emit) {
      if (!state.busy && !state.saved) emit(state.copyWith(draft: event.draft));
    });
    on<UserSaveRequested>(_save);
    on<UserInviteRequested>(_invite);
  }
  final UsersRepository repository;
  final List<UserCorporate> catalog;
  final ManagedUser? user;

  /// Includes inactive sales users: disabling an account does not free its assignments.
  SalesAssignment? ownerOf(String corporateId) {
    for (final candidate in state.assignments) {
      if (candidate.userId != user?.id && candidate.corporateId == corporateId) {
        return candidate;
      }
    }
    return null;
  }

  Future<void> _load(UserEditorOpened event, Emitter<UserEditorState> emit) async {
    if (state.saving) return;
    emit(state.copyWith(loading: true, assignmentsLoaded: false));
    try {
      final assignments = await repository.assignments();
      if (!emit.isDone) {
        emit(state.copyWith(assignments: assignments, loading: false, assignmentsLoaded: true));
      }
    } catch (error) {
      if (!emit.isDone) emit(state.copyWith(loading: false, error: error));
    }
  }

  String? validate() {
    final draft = state.draft;
    if (draft.fullName.trim().isEmpty || draft.fullName.trim().runes.length > 120 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(draft.fullName) || draft.email.trim().isEmpty) {
      return 'REQUIRED';
    }
    if (user == null && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(draft.email.trim())) {
      return 'INVALID_EMAIL';
    }
    if (draft.userType == 'corporate' && !catalog.any((c) => c.id == draft.corporateId)) {
      return 'CORPORATE_REQUIRED';
    }
    if (draft.userType == 'platform' && draft.role == UserRole.sales) {
      if (draft.corporateIds.isEmpty) return 'SALES_CORPORATE_REQUIRED';
      if (draft.corporateIds.any((id) =>
          !catalog.any((c) => c.id == id) || ownerOf(id) != null)) {
        return 'CORPORATE_ALREADY_ASSIGNED';
      }
    }
    return null;
  }

  Future<void> _save(UserSaveRequested event, Emitter<UserEditorState> emit) async {
    if (state.busy || state.saved || !state.assignmentsLoaded) return;
    final problem = validate();
    if (problem != null) {
      emit(state.copyWith(error: UserValidationFailure(problem)));
      return;
    }
    emit(state.copyWith(saving: true));
    try {
      if (user case final existing?) {
        await repository.update(existing.id, state.draft);
        if (!emit.isDone) emit(state.copyWith(saving: false, saved: true));
      } else {
        final result = await repository.create(state.draft);
        if (!emit.isDone) {
          emit(state.copyWith(saving: false, saved: true, invite: result.invite));
        }
      }
    } catch (error) {
      if (emit.isDone) return;
      if (error is ApiFailure && error.code == 'CORPORATE_ALREADY_ASSIGNED') {
        // A concurrent admin may have taken an assignment after the dialog opened.
        try {
          final assignments = await repository.assignments();
          if (!emit.isDone) emit(state.copyWith(assignments: assignments, saving: false, error: error));
        } catch (_) {
          if (!emit.isDone) {
            emit(state.copyWith(saving: false, assignmentsLoaded: false, error: error));
          }
        }
      } else {
        emit(state.copyWith(saving: false, error: error));
      }
    }
  }

  Future<void> _invite(UserInviteRequested event, Emitter<UserEditorState> emit) async {
    if (state.busy || user == null || user!.status != UserStatus.pending) return;
    emit(state.copyWith(saving: true));
    try {
      final invite = await repository.invite(user!.id);
      if (!emit.isDone) emit(state.copyWith(saving: false, invite: invite));
    } catch (error) {
      if (!emit.isDone) emit(state.copyWith(saving: false, error: error));
    }
  }
}
