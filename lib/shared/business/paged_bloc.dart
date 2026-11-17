import 'package:flutter_bloc/flutter_bloc.dart';
import 'page_query.dart';

class PageRequested {
  const PageRequested(this.query);
  final PageQuery query;
}
class PagedState<T> {
  const PagedState({required this.query, this.data, this.loading = true, this.error});
  final PageQuery query;
  final PageResult<T>? data;
  final bool loading;
  final Object? error;
}
/// Owns read requests and discards responses from superseded searches/pages.
class PagedBloc<T> extends Bloc<PageRequested, PagedState<T>> {
  PagedBloc(this.load, PageQuery initial) : super(PagedState(query: initial)) {
    on<PageRequested>((event, emit) async {
      final revision = ++_revision;
      emit(PagedState(query: event.query));
      try {
        var result = await load(event.query);
        if (emit.isDone || revision != _revision) return;
        // Deleting the last item on a page should return to the last available page.
        var query = event.query;
        final last = (result.total / result.pageSize).ceil().clamp(1, 1 << 30);
        if (query.page > last) {
          query = query.copyWith(page: last);
          result = await load(query);
        }
        if (!emit.isDone && revision == _revision) emit(PagedState(query: query, data: result, loading: false));
      } catch (error) {
        if (!emit.isDone && revision == _revision) emit(PagedState(query: event.query, loading: false, error: error));
      }
    });
  }
  final Future<PageResult<T>> Function(PageQuery) load;
  int _revision = 0;
}
