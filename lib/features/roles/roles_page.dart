import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/portal_api.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/business_table.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/business/json_read.dart';
import '../../shared/business/resource_bloc.dart';
import '../../shared/widgets/corporate_scope.dart';

class RoleDefinition {
  const RoleDefinition({required this.id, required this.name, required this.description, required this.permissions});
  factory RoleDefinition.fromJson(Map<String, dynamic> j) {
    final permissions = j['permissions'];
    if (permissions is! List || permissions.any((p) => p is! String)) throw const FormatException('Expected permissions');
    return RoleDefinition(id: j.string('id'), name: j.string('name'), description: j.string('description'), permissions: List.unmodifiable(permissions.cast<String>()));
  }
  final String id, name, description;
  final List<String> permissions;
}

abstract interface class RolesRepository {
  Future<List<RoleDefinition>> list();
}

class ApiRolesRepository implements RolesRepository {
  ApiRolesRepository(this.api);
  final PortalApi api;
  @override
  Future<List<RoleDefinition>> list() async => jsonList(jsonObject(await api.request('GET', '/roles'))['items'], RoleDefinition.fromJson);
}

typedef _RolesBloc = ResourceBloc<List<RoleDefinition>>;

/// Read-only role catalog (System admin only; the server requires user.manage).
class RolesPage extends StatelessWidget {
  const RolesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final repository = ApiRolesRepository(context.read<PortalApi>());
    return BlocProvider(create: (_) => _RolesBloc(repository.list)..add(ResourceRequested()), child: const _RolesView());
  }
}

class _RolesView extends StatelessWidget {
  const _RolesView();

  String _label(BuildContext context, RoleDefinition role) => switch (role.id) {
    'admin' => context.tr('System administrator', 'ผู้ดูแลระบบ'),
    'sales' => context.tr('Sales', 'ฝ่ายขาย'),
    'corporate' => context.tr('Corporate administrator', 'ผู้ดูแลองค์กร'),
    _ => role.name,
  };

  String _description(BuildContext context, RoleDefinition role) => switch (role.id) {
    'admin' => context.tr('Manages every corporate, portal users and platform reports.', 'ดูแลทุกองค์กร ผู้ใช้งานพอร์ทัล และรายงานภาพรวม'),
    'sales' => context.tr('Operates assigned corporates and their platform reports; cannot manage users.', 'ดูแลองค์กรที่ได้รับมอบหมายและรายงานภาพรวมขององค์กรนั้น ไม่สามารถจัดการผู้ใช้'),
    'corporate' => context.tr('Administers one corporate organization.', 'ดูแลองค์กรของตนเองหนึ่งองค์กร'),
    _ => role.description,
  };

  void _details(BuildContext context, RoleDefinition role) => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
    title: Text(context.tr('Permissions', 'สิทธิ์การใช้งาน')),
    content: SizedBox(width: 600, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(_label(context, role), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(_description(context, role)),
      const SizedBox(height: 16),
      if (role.permissions.isEmpty) const BusinessFeedback()
      else for (final permission in role.permissions) Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)),
        child: SelectableText(permission),
      ),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.tr('Close', 'ปิด')))],
  ));

  @override
  Widget build(BuildContext context) => BlocBuilder<_RolesBloc, ResourceState<List<RoleDefinition>>>(builder: (context, state) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title: context.tr('Roles & permissions', 'บทบาทและสิทธิ์')),
      const SizedBox(height: 20),
      if (state.loading || state.data == null) BusinessFeedback(loading: state.loading, error: state.error, retry: () => context.read<_RolesBloc>().add(ResourceRequested()))
      else BusinessCard(child: BusinessTable<RoleDefinition>(
        rows: state.data!,
        id: (r) => r.id,
        columns: [
          BusinessColumn(context.tr('Role', 'บทบาท'), (r) => Text(_label(context, r)), sortValue: (r) => _label(context, r)),
          BusinessColumn(context.tr('Description', 'รายละเอียด'), (r) => ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(_description(context, r)))),
          BusinessColumn(context.tr('Permission count', 'จำนวนสิทธิ์'), (r) => Text('${r.permissions.length}'), sortValue: (r) => '${r.permissions.length}'.padLeft(6, '0')),
        ],
        actions: (r) => IconButton(tooltip: context.tr('Details', 'รายละเอียด'), icon: const Icon(Icons.visibility_outlined), onPressed: () => _details(context, r)),
      )),
    ]),
  ));
}
