import 'package:material_ui/material_ui.dart';
import '../../core/i18n/locale_cubit.dart';

class BusinessColumn<T> {
  const BusinessColumn(this.title, this.cell, {this.sortValue});
  final String title;
  final Widget Function(T row) cell;
  final String Function(T row)? sortValue;
}

/// Pagination limits the visible row count; horizontal scrolling preserves table readability.
class BusinessTable<T> extends StatefulWidget {
  const BusinessTable({super.key, required this.rows, required this.columns, required this.id,
    this.searchText, this.filters, this.actions, this.selected, this.onSelectionChanged});
  final List<T> rows;
  final List<BusinessColumn<T>> columns;
  final String Function(T row) id;
  final String Function(T row)? searchText;
  final Widget? filters;
  final Widget Function(T row)? actions;
  final Set<String>? selected;
  final ValueChanged<Set<String>>? onSelectionChanged;
  @override
  State<BusinessTable<T>> createState() => _BusinessTableState<T>();
}

class _BusinessTableState<T> extends State<BusinessTable<T>> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  int _page = 0, _size = 10;
  int? _sort;
  bool _ascending = true;
  @override
  void dispose() { _search.dispose(); _scroll.dispose(); super.dispose(); }
  @override
  void didUpdateWidget(covariant BusinessTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rows, widget.rows)) _page = 0;
  }
  void _select(String id, bool selected) {
    final ids = {...?widget.selected};
    selected ? ids.add(id) : ids.remove(id);
    widget.onSelectionChanged?.call(ids);
  }
  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final rows = widget.rows.where((row) => query.isEmpty || (widget.searchText?.call(row).toLowerCase().contains(query) ?? true)).toList();
    final sortValue = _sort == null ? null : widget.columns[_sort!].sortValue;
    if (sortValue != null) rows.sort((a, b) => _ascending ? sortValue(a).compareTo(sortValue(b)) : sortValue(b).compareTo(sortValue(a)));
    final pages = (rows.length / _size).ceil().clamp(1, 1000000000);
    final page = _page.clamp(0, pages - 1);
    final displayed = rows.skip(page * _size).take(_size).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (widget.searchText != null) SizedBox(width: 280, child: TextField(controller: _search, decoration: InputDecoration(labelText: context.tr('Search', 'ค้นหา'), prefixIcon: const Icon(Icons.search), suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: context.tr('Clear', 'ล้าง'), onPressed: () => setState(() { _search.clear(); _page = 0; widget.onSelectionChanged?.call({}); }), icon: const Icon(Icons.close))), onChanged: (_) => setState(() { _page = 0; widget.onSelectionChanged?.call({}); }))),
        if (widget.filters != null) widget.filters!,
      ]),
      const SizedBox(height: 16),
      if (displayed.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(query.isEmpty ? context.tr('No records', 'ไม่มีรายการ') : context.tr('No matching records', 'ไม่มีข้อมูลที่ตรงกับการค้นหา'), textAlign: TextAlign.center))
      else Scrollbar(controller: _scroll, thumbVisibility: true, child: SingleChildScrollView(controller: _scroll, scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(bottom: 14), child: DataTable(
        sortColumnIndex: _sort, sortAscending: _ascending,
        onSelectAll: widget.onSelectionChanged == null ? null : (selected) {
          final ids = {...?widget.selected};
          for (final row in displayed) { selected == true ? ids.add(widget.id(row)) : ids.remove(widget.id(row)); }
          widget.onSelectionChanged!(ids);
        },
        columns: [for (var index = 0; index < widget.columns.length; index++) DataColumn(label: Text(widget.columns[index].title), onSort: widget.columns[index].sortValue == null ? null : (_, ascending) => setState(() { _sort = index; _ascending = ascending; })), if (widget.actions != null) DataColumn(label: Text(context.tr('Actions', 'การดำเนินการ')))],
        rows: [for (final row in displayed) DataRow(selected: widget.selected?.contains(widget.id(row)) ?? false, onSelectChanged: widget.onSelectionChanged == null ? null : (selected) => _select(widget.id(row), selected == true), cells: [for (final column in widget.columns) DataCell(column.cell(row)), if (widget.actions != null) DataCell(widget.actions!(row))])],
      ))),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 8, children: [
        Text('${rows.length} ${context.tr('records', 'รายการ')}'),
        Row(mainAxisSize: MainAxisSize.min, children: [
          DropdownButton<int>(value: _size, items: [10, 25, 50, 100].map((size) => DropdownMenuItem(value: size, child: Text('$size'))).toList(), onChanged: (size) => setState(() { _size = size!; _page = 0; })),
          IconButton(tooltip: context.tr('Previous page', 'หน้าก่อนหน้า'), onPressed: page == 0 ? null : () => setState(() => _page = page - 1), icon: const Icon(Icons.chevron_left)),
          Text('${page + 1} / $pages'),
          IconButton(tooltip: context.tr('Next page', 'หน้าถัดไป'), onPressed: page + 1 >= pages ? null : () => setState(() => _page = page + 1), icon: const Icon(Icons.chevron_right)),
        ]),
      ]),
    ]);
  }
}
