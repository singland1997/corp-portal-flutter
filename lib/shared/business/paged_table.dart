import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/i18n/locale_cubit.dart';
import 'business_widgets.dart';
import 'page_query.dart';
import 'paged_bloc.dart';
export 'page_query.dart';

class RemoteColumn<T> {
  const RemoteColumn(this.label, this.cell, {this.sortKey});
  final String label;
  final Widget Function(T) cell;
  final String? sortKey;
}

/// SQL-backed pages. Search/sort/page changes never operate on only the visible rows.
class RemoteTable<T> extends StatefulWidget {
  const RemoteTable({super.key, required this.load, required this.columns, required this.id,
    this.initialQuery = const PageQuery(), this.filters, this.actions, this.selected,
    this.onSelectionChanged, this.onQueryChanged, this.onLoaded});
  final Future<PageResult<T>> Function(PageQuery) load;
  final List<RemoteColumn<T>> columns;
  final String Function(T) id;
  final PageQuery initialQuery;
  final Widget? filters;
  final Widget Function(T)? actions;
  final Set<String>? selected;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final ValueChanged<PageQuery>? onQueryChanged;
  final ValueChanged<PageResult<T>>? onLoaded;
  @override State<RemoteTable<T>> createState() => _RemoteTableState<T>();
}
class _RemoteTableState<T> extends State<RemoteTable<T>> {
  late final _bloc = PagedBloc<T>((q) => widget.load(q), widget.initialQuery)..add(PageRequested(widget.initialQuery));
  late final _search = TextEditingController(text: widget.initialQuery.search);
  final _scroll = ScrollController();
  Timer? _debounce;
  @override void initState() { super.initState(); _bloc; }
  @override void dispose() { _debounce?.cancel(); _bloc.close(); _search.dispose(); _scroll.dispose(); super.dispose(); }
  @override void didUpdateWidget(covariant RemoteTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.initialQuery.sameAs(widget.initialQuery)) {
      _debounce?.cancel();
      final query = _bloc.state.query.copyWith(page: 1, filters: widget.initialQuery.filters);
      // Parent filters may change without losing the user's current search/sort.
      _bloc.add(PageRequested(query));
    }
  }
  void _request(PageQuery query) {
    _debounce?.cancel();
    widget.onSelectionChanged?.call({});
    widget.onQueryChanged?.call(query);
    _bloc.add(PageRequested(query));
  }
  @override Widget build(BuildContext context) => BlocConsumer<PagedBloc<T>, PagedState<T>>(
    bloc: _bloc,
    listener: (_, state) {
      if (state.data != null) { widget.onLoaded?.call(state.data!); widget.onQueryChanged?.call(state.query); }
    },
    builder: (context, state) {
      final q = state.query, data = state.data;
      final pages = data == null ? 1 : (data.total / data.pageSize).ceil().clamp(1, 1 << 30);
      final sortIndex = widget.columns.indexWhere((c) => c.sortKey == q.sort);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: TextField(
            controller: _search, maxLength: 200,
            decoration: InputDecoration(counterText: '', labelText: context.tr('Search', 'ค้นหา'), prefixIcon: const Icon(Icons.search)),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => _request(_bloc.state.query.copyWith(page: 1, search: value.trim())));
            },
            onSubmitted: (value) => _request(q.copyWith(page: 1, search: value.trim())),
          )),
          if (widget.filters != null) widget.filters!,
        ]),
        const SizedBox(height: 16),
        if (state.loading) const LinearProgressIndicator()
        else if (state.error != null) BusinessFeedback(error: state.error, retry: () => _request(q))
        else if (data == null || data.items.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(context.tr('No matching records', 'ไม่มีข้อมูลที่ตรงกับการค้นหา')))
        else Scrollbar(controller: _scroll, thumbVisibility: true, child: SingleChildScrollView(
          controller: _scroll, scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(bottom: 14),
          child: DataTable(sortColumnIndex: sortIndex < 0 ? null : sortIndex, sortAscending: q.direction == 'asc',
            onSelectAll: widget.onSelectionChanged == null ? null : (selected) => widget.onSelectionChanged!(selected == true ? data.items.map(widget.id).toSet() : {}),
            columns: [for (final c in widget.columns) DataColumn(label: Text(c.label), onSort: c.sortKey == null ? null : (_, ascending) => _request(q.copyWith(page: 1, sort: c.sortKey, direction: ascending ? 'asc' : 'desc'))), if (widget.actions != null) DataColumn(label: Text(context.tr('Actions', 'การดำเนินการ')))],
            rows: [for (final row in data.items) DataRow(selected: widget.selected?.contains(widget.id(row)) ?? false,
              onSelectChanged: widget.onSelectionChanged == null ? null : (selected) { final ids = {...?widget.selected}; selected == true ? ids.add(widget.id(row)) : ids.remove(widget.id(row)); widget.onSelectionChanged!(ids); },
              cells: [for (final c in widget.columns) DataCell(c.cell(row)), if (widget.actions != null) DataCell(widget.actions!(row))])],
          ),
        )),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${data?.total ?? '—'} ${context.tr('records', 'รายการ')}'),
          Row(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<int>(value: q.pageSize, items: [10, 25, 50, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: state.loading ? null : (n) => _request(q.copyWith(page: 1, pageSize: n))),
            IconButton(tooltip: context.tr('Previous page', 'หน้าก่อนหน้า'), onPressed: state.loading || q.page <= 1 ? null : () => _request(q.copyWith(page: q.page - 1)), icon: const Icon(Icons.chevron_left)),
            Text('${q.page} / $pages'),
            IconButton(tooltip: context.tr('Next page', 'หน้าถัดไป'), onPressed: state.loading || q.page >= pages ? null : () => _request(q.copyWith(page: q.page + 1)), icon: const Icon(Icons.chevron_right)),
          ]),
        ]),
      ]);
    },
  );
}
