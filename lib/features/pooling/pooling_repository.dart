import '../../core/api/portal_api.dart';
import '../../shared/business/json_read.dart';
import '../../shared/business/page_query.dart';
import 'pooling_models.dart';

abstract interface class PoolingRepository {
  Future<PoolingSnapshot> load(String corporateId);
  /// API pages: search, sort and filters (`pool`, `status`, `department`, `type`, `from`, `to`) run server-side.
  Future<PageResult<DataPool>> pools(String corporateId, PageQuery query);
  Future<PageResult<PoolMember>> members(String corporateId, PageQuery query);
  Future<PageResult<PoolTransaction>> transactions(String corporateId, PageQuery query);
  /// Every transaction of the corporate (CSV export only).
  Future<List<PoolTransaction>> allTransactions(String corporateId);
  Future<void> save(String corporateId, PoolDraft draft, {String? id});
  Future<void> adjust(String corporateId, String poolId, QuotaDraft draft);
}

class ApiPoolingRepository implements PoolingRepository {
  ApiPoolingRepository(this.api);
  final PortalApi api;

  @override
  Future<PoolingSnapshot> load(String corporateId) async {
    Future<dynamic> get(String path) => api.request('GET', path, corporateId: corporateId);
    final results = await Future.wait([get('/pools'), get('/pools/members'), get('/pools/inventory'), get('/pools/capabilities')]);
    final capabilities = jsonObject(results[3]);
    return PoolingSnapshot(
      pools: jsonList(results[0], DataPool.fromJson),
      members: jsonList(results[1], PoolMember.fromJson),
      inventory: jsonList(results[2], PoolInventoryItem.fromJson),
      poolWrite: capabilities.boolean('poolWrite'),
      quotaAdjust: capabilities.boolean('quotaAdjust'),
    );
  }

  Future<PageResult<T>> _page<T>(String corporateId, String path, PageQuery query, T Function(Map<String, dynamic>) item) async =>
    PageResult.fromJson(jsonObject(await api.request('GET', path, query: query.toQuery(), corporateId: corporateId)), item);
  @override
  Future<PageResult<DataPool>> pools(String corporateId, PageQuery query) => _page(corporateId, '/pools/page', query, DataPool.fromJson);
  @override
  Future<PageResult<PoolMember>> members(String corporateId, PageQuery query) => _page(corporateId, '/pools/members/page', query, PoolMember.fromJson);
  @override
  Future<PageResult<PoolTransaction>> transactions(String corporateId, PageQuery query) => _page(corporateId, '/pools/transactions/page', query, PoolTransaction.fromJson);
  @override
  Future<List<PoolTransaction>> allTransactions(String corporateId) async =>
    jsonList(await api.request('GET', '/pools/transactions', corporateId: corporateId), PoolTransaction.fromJson);

  @override
  Future<void> save(String corporateId, PoolDraft draft, {String? id}) async {
    final body = {'name': draft.name.trim(), 'status': draft.status};
    if (id == null) {
      await api.request('POST', '/pools', body: body, corporateId: corporateId);
    } else {
      await api.request('PATCH', '/pools/${Uri.encodeComponent(id)}', body: body, corporateId: corporateId);
    }
  }

  @override
  Future<void> adjust(String corporateId, String poolId, QuotaDraft draft) async {
    await api.request('POST', '/pools/${Uri.encodeComponent(poolId)}/quota-adjustments', corporateId: corporateId, body: {
      'direction': draft.direction,
      'amountMb': toMegabytes(draft.amount, draft.unit),
      'reason': draft.reason.trim(),
    });
  }
}
