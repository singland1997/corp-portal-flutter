import '../../core/api/portal_api.dart';
import '../../shared/business/json_read.dart';
import '../../shared/business/page_query.dart';
import 'corporate_models.dart';

abstract interface class CorporateRepository {
  /// One SQL page of the corporate's numbers (search, status/lot filters and sort run in the API).
  Future<NumberPage> numbers(String corporateId, PageQuery query);
  Future<List<CommandResult>> command(String corporateId, String action, List<String> ids, String key);
}

class ApiCorporateRepository implements CorporateRepository {
  ApiCorporateRepository(this.api);
  final PortalApi api;
  @override
  Future<NumberPage> numbers(String corporateId, PageQuery query) async => NumberPage.fromJson(jsonObject(await api.request(
    'GET', '/corporates/${Uri.encodeComponent(corporateId)}/numbers', query: query.toQuery(), corporateId: corporateId)));
  @override
  Future<List<CommandResult>> command(String corporateId, String action, List<String> ids, String key) async {
    if (!{'suspend', 'resume'}.contains(action)) throw ArgumentError.value(action);
    final response = jsonObject(await api.request('POST', '/corporates/${Uri.encodeComponent(corporateId)}/numbers/$action', body: {'ids': ids}, corporateId: corporateId, idempotencyKey: key));
    return jsonList(response['results'], CommandResult.fromJson);
  }
}
