import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'corporate_models.dart';
import 'corporate_repository.dart';

sealed class CorporateEvent {}
/// The number table loaded a page; its summary (counts, lots, capabilities) is the corporate's.
final class CorporateSummaryLoaded extends CorporateEvent {
  CorporateSummaryLoaded(this.summary);
  final NumberPage summary;
}
final class NumberCommandRequested extends CorporateEvent {
  NumberCommandRequested(this.action, this.ids);
  final String action;
  final List<String> ids;
}

class CorporateState {
  const CorporateState({this.summary, this.busy = false, this.commandError, this.results = const []});
  /// Latest page response; `null` until the first page arrives.
  final NumberPage? summary;
  final bool busy;
  final Object? commandError;
  final List<CommandResult> results;
  CorporateState copyWith({NumberPage? summary}) => CorporateState(summary: summary ?? this.summary, busy: busy, commandError: commandError, results: results);
}

/// Number commands for one corporate. Rows are paged by the table, not held here.
class CorporateBloc extends Bloc<CorporateEvent, CorporateState> {
  CorporateBloc(this.repository, this.corporateId) : super(const CorporateState()) {
    on<CorporateSummaryLoaded>((event, emit) => emit(state.copyWith(summary: event.summary)));
    on<NumberCommandRequested>((event, emit) async {
      final summary = state.summary;
      if (state.busy || event.ids.isEmpty || summary == null) return;
      if (!(event.action == 'suspend' ? summary.canSuspend : summary.canResume)) return;
      final signature = '${event.action}:${(event.ids.toList()..sort()).join(',')}';
      if (_signature != signature) { _key = const Uuid().v4(); _signature = signature; }
      emit(CorporateState(summary: summary, busy: true));
      try {
        final results = await repository.command(corporateId, event.action, event.ids, _key!);
        // Accepted is not completed. Projection status changes only after CRM synchronization.
        if (!emit.isDone) emit(CorporateState(summary: state.summary, results: results));
        _signature = null;
      } catch (error) {
        // Keep the idempotency key for retrying an ambiguous network failure.
        if (!emit.isDone) emit(CorporateState(summary: state.summary, commandError: error));
      }
    });
  }
  final CorporateRepository repository;
  final String corporateId;
  String? _signature, _key;
}
