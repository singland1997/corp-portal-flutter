import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ResourceEvent {}
final class ResourceRequested extends ResourceEvent {}

class ResourceState<T> {
  const ResourceState({this.data, this.loading = false, this.error});
  final T? data;
  final bool loading;
  final Object? error;
}

/// Read-only resource. Sequence guard prevents a slower reload overwriting newer data.
class ResourceBloc<T> extends Bloc<ResourceEvent, ResourceState<T>> {
  // Starts as loading: every page adds ResourceRequested right away, so no "no data" flash.
  ResourceBloc(this.load) : super(ResourceState<T>(loading: true)) {
    on<ResourceRequested>((event, emit) async {
      final generation = ++_generation;
      emit(ResourceState<T>(loading: true));
      try {
        final result = await load();
        if (!emit.isDone && generation == _generation) emit(ResourceState(data: result));
      } catch (error) {
        if (!emit.isDone && generation == _generation) emit(ResourceState<T>(error: error));
      }
    });
  }
  final Future<T> Function() load;
  int _generation = 0;
}
