import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/locale_cubit.dart';
import '../../../shared/widgets/searchable_select.dart';
import '../bloc/user_editor_bloc.dart';
import '../data/user_models.dart';
import 'user_labels.dart';

class UserScopeFields extends StatelessWidget {
  const UserScopeFields({super.key, required this.state, required this.self});
  final UserEditorState state;
  final bool self;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<UserEditorBloc>();
    final draft = state.draft;
    final selected = bloc.catalog.any((c) => c.id == draft.corporateId) ? draft.corporateId : null;
    void change(UserDraft value) => bloc.add(UserDraftChanged(value));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RequiredLabel(context.tr('User type', 'ประเภทผู้ใช้')),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'corporate', label: Text(context.tr('Corporate', 'องค์กร'))),
          ButtonSegment(value: 'platform', label: Text(context.tr('Platform', 'ส่วนกลาง'))),
        ],
        selected: {draft.userType},
        onSelectionChanged: bloc.user == null ? (value) => change(draft.copyWith(userType: value.single)) : null,
      ),
      const SizedBox(height: 16),
      if (draft.userType == 'corporate')
        SearchableSelect(
          label: RequiredLabel(context.tr('Corporate', 'องค์กร')),
          options: [for (final c in bloc.catalog) SelectOption(c.id, corporateLabel(context, c))],
          selected: {?selected},
          emptyText: context.tr('No corporates available', 'ไม่มีองค์กรให้เลือก'),
          onChanged: (ids) => change(bloc.state.draft.copyWith(corporateId: ids.firstOrNull)),
        )
      else ...[
        DropdownButtonFormField<UserRole>(
          initialValue: draft.role,
          isExpanded: true,
          decoration: InputDecoration(label: RequiredLabel(context.tr('User role', 'บทบาทผู้ใช้'))),
          items: [UserRole.admin, UserRole.sales].map((role) => DropdownMenuItem(value: role, child: Text(roleLabel(context, role)))).toList(),
          onChanged: self ? null : (role) => change(draft.copyWith(role: role)),
        ),
        if (draft.role == UserRole.sales) ...[
          const SizedBox(height: 16),
          SearchableSelect(
            multiple: true,
            label: RequiredLabel(context.tr('Assigned corporates', 'องค์กรที่ดูแล')),
            options: [
              for (final corporate in bloc.catalog)
                if (bloc.ownerOf(corporate.id) case final owner)
                  // A corporate another Sales user owns is shown but cannot be picked;
                  // a stale, now unavailable selection can still be removed.
                  SelectOption(
                    corporate.id,
                    corporateLabel(context, corporate),
                    subtitle: owner == null ? null : '${context.tr('Assigned to', 'ผู้ดูแล:')} ${owner.name}',
                    enabled: owner == null,
                  ),
            ],
            selected: draft.corporateIds.toSet(),
            emptyText: context.tr('No corporates available', 'ไม่มีองค์กรให้เลือก'),
            onChanged: (ids) => change(bloc.state.draft.copyWith(corporateIds: ids.toList())),
          ),
        ],
      ],
    ]);
  }
}
