import '../../../core/api/portal_api.dart';
import 'user_models.dart';
import '../../../shared/business/page_query.dart';

abstract interface class UsersRepository {
  Future<PageResult<ManagedUser>> page(PageQuery query);
  Future<List<SalesAssignment>> assignments();
  Future<CreatedUser> create(UserDraft draft);
  Future<ManagedUser> update(String id, UserDraft draft);
  Future<UserInvite> invite(String id);
}

class ApiUsersRepository implements UsersRepository {
  ApiUsersRepository(this.api);
  final PortalApi api;

  @override
  Future<PageResult<ManagedUser>> page(PageQuery query) async {
    final result = await api.request('GET', '/users/page', query: query.toQuery()) as Map<String, dynamic>;
    return PageResult(items: List.unmodifiable((result['items'] as List).map((row) => ManagedUser.fromJson(row as Map<String, dynamic>))),
      total: result['total'] as int, page: result['page'] as int, pageSize: result['pageSize'] as int);
  }

  @override
  Future<List<SalesAssignment>> assignments() async {
    final result = await api.request('GET', '/users/sales-assignments') as List;
    return List.unmodifiable(result.map((row) => SalesAssignment.fromJson(row as Map<String, dynamic>)));
  }

  @override
  Future<CreatedUser> create(UserDraft draft) async {
    final json = await api.request('POST', '/users', body: draft.createBody())
        as Map<String, dynamic>;
    return CreatedUser(ManagedUser.fromJson(json), UserInvite.fromJson(json));
  }

  @override
  Future<ManagedUser> update(String id, UserDraft draft) async =>
      ManagedUser.fromJson(
        await api.request(
              'PATCH',
              '/users/${Uri.encodeComponent(id)}',
              body: draft.updateBody(),
            )
            as Map<String, dynamic>,
      );

  @override
  Future<UserInvite> invite(String id) async => UserInvite.fromJson(
    await api.request(
          'POST',
          '/users/${Uri.encodeComponent(id)}/invite',
          body: {},
        )
        as Map<String, dynamic>,
  );
}
