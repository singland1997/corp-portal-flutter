import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/portal_api.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/paged_table.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/widgets/corporate_scope.dart';
import '../auth/bloc/auth_bloc.dart';
import 'data/user_models.dart';
import 'data/users_repository.dart';
import 'widgets/user_editor_dialog.dart';
import 'widgets/user_labels.dart';

/// System-admin directory. Only the requested page is downloaded and rendered.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override State<UsersPage> createState() => _UsersPageState();
}
class _UsersPageState extends State<UsersPage> {
  late final UsersRepository _repository = ApiUsersRepository(context.read<PortalApi>());
  PageQuery _query = const PageQuery(sort: 'name');
  PageQuery _initialQuery = const PageQuery(sort: 'name');
  int _revision = 0;
  bool _saved = false;
  UserRole? _role;
  UserStatus? _status;
  String? _corporate;

  List<UserCorporate> _catalog() => [
    for (final c in context.read<AuthBloc>().state.user?.corporates ?? const [])
      UserCorporate(id: c.id, name: c.name, nameTh: c.nameTh),
  ];
  Future<void> _open([ManagedUser? user]) async {
    final auth = context.read<AuthBloc>().state;
    setState(() => _saved = false);
    final saved = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => UserEditorDialog(repository: _repository, catalog: _catalog(),
        actorId: auth.user!.id, user: user, selectedCorporate: auth.corporateId));
    if (!mounted || saved != true) return;
    setState(() { _saved = true; _initialQuery = _query; _revision++; });
  }
  void _filter() => setState(() {
    _query = _query.copyWith(page: 1, filters: {
      if (_role != null) 'role': _role!.name,
      if (_status != null) 'status': _status!.name,
      'corporate': ?_corporate,
    });
    _initialQuery = _query;
  });

  @override Widget build(BuildContext context) {
    final catalog = _catalog();
    String corporateText(ManagedUser user) => user.role == UserRole.sales
        ? user.corporates.map((c) => corporateLabel(context, c)).join(', ')
        : user.corporateName ?? context.tr('Platform', 'ส่วนกลาง');
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title: context.tr('User management', 'จัดการผู้ใช้งาน'), actions: [
        FilledButton.icon(onPressed: () => _open(), icon: const Icon(Icons.add), label: Text(context.tr('Create user', 'สร้างผู้ใช้'))),
      ]),
      const SizedBox(height: 20),
      if (_saved) ...[Notice(context.tr('User saved.', 'บันทึกผู้ใช้แล้ว'), kind: NoticeKind.success), const SizedBox(height: 16)],
      BusinessCard(title: context.tr('Users', 'ผู้ใช้งาน'), child: RemoteTable<ManagedUser>(
        key: ValueKey(_revision), load: _repository.page, initialQuery: _initialQuery,
        onQueryChanged: (query) => _query = query,
        id: (u) => u.id,
        filters: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: DropdownButtonFormField<String?>(
            key: ValueKey('corporate:$_corporate'), initialValue: _corporate, isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('Corporate', 'องค์กร')),
            items: [
              DropdownMenuItem(value: null, child: Text(context.tr('All corporates', 'ทุกองค์กร'))),
              DropdownMenuItem(value: 'platform', child: Text(context.tr('Platform', 'ส่วนกลาง'))),
              for (final c in catalog) DropdownMenuItem(value: c.id, child: Text(corporateLabel(context, c), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) { _corporate = value; _filter(); },
          )),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: DropdownButtonFormField<UserRole?>(
            key: ValueKey('role:$_role'), initialValue: _role, isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('Role', 'บทบาท')),
            items: [
              DropdownMenuItem(value: null, child: Text(context.tr('All roles', 'ทุกบทบาท'))),
              for (final role in UserRole.values) DropdownMenuItem(value: role, child: Text(roleLabel(context, role))),
            ],
            onChanged: (value) { _role = value; _filter(); },
          )),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: DropdownButtonFormField<UserStatus?>(
            key: ValueKey('status:$_status'), initialValue: _status, isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('Status', 'สถานะ')),
            items: [
              DropdownMenuItem(value: null, child: Text(context.tr('All statuses', 'ทุกสถานะ'))),
              for (final status in UserStatus.values) DropdownMenuItem(value: status, child: Text(statusLabel(context, status))),
            ],
            onChanged: (value) { _status = value; _filter(); },
          )),
          IconButton(tooltip: context.tr('Clear filters', 'ล้างตัวกรอง'), icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: () { _role = null; _status = null; _corporate = null; _filter(); }),
        ]),
        columns: [
          RemoteColumn(context.tr('Name', 'ชื่อ'), (u) => Text(u.name), sortKey: 'name'),
          RemoteColumn(context.tr('Email', 'อีเมล'), (u) => Text(u.email), sortKey: 'email'),
          RemoteColumn(context.tr('Corporate', 'องค์กร'), (u) => ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: Text(corporateText(u), overflow: TextOverflow.ellipsis))),
          RemoteColumn(context.tr('Role', 'บทบาท'), (u) => Text(roleLabel(context, u.role)), sortKey: 'role'),
          RemoteColumn(context.tr('Status', 'สถานะ'), (u) => BusinessStatus(u.status.name), sortKey: 'status'),
        ],
        actions: (u) => IconButton(tooltip: context.tr('Edit', 'แก้ไข'), icon: const Icon(Icons.edit_outlined), onPressed: () => _open(u)),
      )),
    ]));
  }
}
