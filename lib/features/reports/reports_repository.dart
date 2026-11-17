import '../../core/api/portal_api.dart';
import '../../shared/business/page_query.dart';

/// Schema-defined columns with scalar cells; missing values remain unknown.
class ReportRow {
  ReportRow(Map<String, Object?> values) : values = Map.unmodifiable(values);
  final Map<String, Object?> values;
  factory ReportRow.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Invalid report row');
    for (final value in json.values) {
      if (value != null && value is! String && !(value is num && value.isFinite)) {
        throw const FormatException('Invalid report cell');
      }
    }
    return ReportRow(json);
  }
}

abstract interface class ReportsRepository {
  /// One API page of report rows (search and sort run server-side).
  Future<PageResult<ReportRow>> page(String corporateId, String reportId, PageQuery query, {String? from, String? to});
  /// Every row (CSV export).
  Future<List<ReportRow>> load(String corporateId, String reportId, {String? from, String? to});
}

class ApiReportsRepository implements ReportsRepository {
  ApiReportsRepository(this.api);
  final PortalApi api;
  @override
  Future<PageResult<ReportRow>> page(String corporateId, String reportId, PageQuery query, {String? from, String? to}) async {
    final response = await api.request('GET', '/reports/${Uri.encodeComponent(reportId)}/page',
      corporateId: corporateId, query: {...query.toQuery(), 'from': ?from, 'to': ?to});
    if (response is! Map<String, dynamic> || response['items'] is! List) throw const FormatException('Invalid report response');
    return PageResult.fromJson(response, ReportRow.fromJson);
  }
  @override
  Future<List<ReportRow>> load(String corporateId, String reportId, {String? from, String? to}) async {
    final response = await api.request('GET', '/reports/${Uri.encodeComponent(reportId)}',
      corporateId: corporateId, query: {'from': ?from, 'to': ?to});
    if (response is! Map<String, dynamic> || response['report'] != reportId || response['rows'] is! List) {
      throw const FormatException('Invalid report response');
    }
    return (response['rows'] as List).map(ReportRow.fromJson).toList(growable: false);
  }
}
