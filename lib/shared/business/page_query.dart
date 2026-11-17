class PageQuery {
  const PageQuery({this.page = 1, this.pageSize = 10, this.search = '', this.sort = 'id', this.direction = 'asc', this.filters = const {}});
  final int page, pageSize;
  final String search, sort, direction;
  final Map<String, String> filters;
  PageQuery copyWith({int? page, int? pageSize, String? search, String? sort, String? direction, Map<String, String>? filters}) => PageQuery(
    page: page ?? this.page, pageSize: pageSize ?? this.pageSize, search: search ?? this.search,
    sort: sort ?? this.sort, direction: direction ?? this.direction, filters: filters ?? this.filters,
  );
  Map<String, String> toQuery() => {...filters, 'page': '$page', 'pageSize': '$pageSize', 'search': search, 'sort': sort, 'direction': direction};
  bool sameAs(PageQuery other) {
    final a = toQuery(), b = other.toQuery();
    return a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
  }
}

class PageResult<T> {
  const PageResult({required this.items, required this.total, required this.page, required this.pageSize, this.revision});
  /// `{items, total, page, pageSize}` from any paged endpoint.
  factory PageResult.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) item) => PageResult(
    items: List.unmodifiable((json['items'] as List).map((row) => item(row as Map<String, dynamic>))),
    total: (json['total'] as num).toInt(), page: (json['page'] as num).toInt(), pageSize: (json['pageSize'] as num).toInt(),
    revision: json['revision'] as String?,
  );

  final List<T> items;
  final int total, page, pageSize;
  final String? revision;
}
