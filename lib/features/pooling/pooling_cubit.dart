import 'package:flutter_bloc/flutter_bloc.dart';
import 'pooling_models.dart';
import 'pooling_repository.dart';

class PoolingState {
  const PoolingState({this.data, this.loading = false, this.error, this.busy = false, this.mutationError});
  final PoolingSnapshot? data;
  final bool loading, busy;
  final Object? error, mutationError;
  List<DataPool> get pools => data?.pools ?? const [];
  PoolingState copyWith({PoolingSnapshot? data, bool? loading, bool? busy, Object? error, Object? mutationError}) => PoolingState(
    data: data ?? this.data, loading: loading ?? this.loading, busy: busy ?? this.busy, error: error, mutationError: mutationError,
  );
}

/// One instance per corporate (page is rebuilt by `CorporateScope` on switch).
class PoolingCubit extends Cubit<PoolingState> {
  // Starts as loading: the page calls load() immediately, so no "no data" flash.
  PoolingCubit(this.repository, this.corporateId) : super(const PoolingState(loading: true));
  final PoolingRepository repository;
  final String corporateId;
  int _generation = 0;

  Future<void> load({bool quiet = false}) async {
    final generation = ++_generation;
    emit(quiet ? state.copyWith(mutationError: state.mutationError) : const PoolingState(loading: true));
    try {
      final data = await repository.load(corporateId);
      if (!isClosed && generation == _generation) emit(PoolingState(data: data));
    } catch (error) {
      if (!isClosed && generation == _generation) emit(quiet ? state.copyWith(error: error) : PoolingState(error: error));
    }
  }

  void clearMutationError() => emit(state.copyWith());

  /// Returns a validation error, `null` on success; throws on API failure (shown via [PoolingState.mutationError]).
  Future<PoolError?> savePool(PoolDraft draft, {String? id}) async {
    final problem = poolError(draft, state.pools, id);
    if (problem != null) return problem;
    await _mutate(() => repository.save(corporateId, draft, id: id));
    return null;
  }

  Future<PoolError?> adjustQuota(String poolId, QuotaDraft draft) async {
    final pool = state.pools.where((p) => p.id == poolId).firstOrNull;
    if (pool == null) return PoolError.poolMissing;
    final problem = quotaError(pool, draft);
    if (problem != null) return problem;
    await _mutate(() => repository.adjust(corporateId, poolId, draft));
    return null;
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    if (state.busy) throw StateError('Mutation in progress');
    emit(state.copyWith(busy: true));
    try {
      await operation();
      if (isClosed) return;
      emit(state.copyWith(busy: false));
      await load(quiet: true);
    } catch (error) {
      if (!isClosed) emit(state.copyWith(busy: false, mutationError: error));
      rethrow;
    }
  }
}
