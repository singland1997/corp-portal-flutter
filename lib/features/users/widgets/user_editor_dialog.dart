import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/locale_cubit.dart';
import '../bloc/user_editor_bloc.dart';
import '../data/user_models.dart';
import '../data/users_repository.dart';
import 'invite_panel.dart';
import 'user_labels.dart';
import 'user_scope_fields.dart';

class UserEditorDialog extends StatelessWidget {
  const UserEditorDialog({super.key, required this.repository, required this.catalog, required this.actorId, this.user, this.selectedCorporate});
  final UsersRepository repository;
  final List<UserCorporate> catalog;
  final String actorId;
  final ManagedUser? user;
  final String? selectedCorporate;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => UserEditorBloc(repository: repository, catalog: catalog, user: user, selectedCorporate: selectedCorporate)..add(UserEditorOpened()),
    child: _Editor(actorId: actorId),
  );
}

class _Editor extends StatelessWidget {
  const _Editor({required this.actorId});
  final String actorId;

  @override
  Widget build(BuildContext context) => BlocConsumer<UserEditorBloc, UserEditorState>(
    listenWhen: (previous, state) => !previous.saved && state.saved,
    listener: (context, state) {
      if (context.read<UserEditorBloc>().user != null) Navigator.of(context).pop(true);
    },
    builder: (context, state) {
      final bloc = context.read<UserEditorBloc>();
      final user = bloc.user;
      final draft = state.draft;
      void change(UserDraft next) => bloc.add(UserDraftChanged(next));
      return PopScope(
        canPop: !state.busy,
        child: AlertDialog(
          insetPadding: const EdgeInsets.all(16),
          title: Text(user == null ? context.tr('Create user', 'สร้างผู้ใช้') : context.tr('Edit user', 'แก้ไขผู้ใช้')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                if (state.loading) const LinearProgressIndicator(),
                if (!state.saved) AbsorbPointer(
                  absorbing: state.busy,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    UserScopeFields(state: state, self: user?.id == actorId),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: draft.fullName,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(label: RequiredLabel(context.tr('Full name', 'ชื่อ-นามสกุล')), counterText: ''),
                      onChanged: (value) => change(bloc.state.draft.copyWith(fullName: value)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: draft.email,
                      readOnly: user != null,
                      maxLength: 254,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(label: RequiredLabel(context.tr('Email', 'อีเมล')), counterText: ''),
                      onChanged: (value) => change(bloc.state.draft.copyWith(email: value)),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<UserStatus>(
                        initialValue: draft.status,
                        isExpanded: true,
                        decoration: InputDecoration(label: RequiredLabel(context.tr('Status', 'สถานะ'))),
                        items: UserStatus.values.map((status) => DropdownMenuItem(
                          value: status,
                          enabled: !(user.status == UserStatus.pending && status == UserStatus.active),
                          child: Text(statusLabel(context, status)),
                        )).toList(),
                        onChanged: user.id == actorId ? null : (value) => change(draft.copyWith(status: value)),
                      ),
                    ],
                  ]),
                ),
                if (state.error case final error?) ...[
                  const SizedBox(height: 16),
                  Text(userError(context, error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  if (!state.assignmentsLoaded && !state.busy) TextButton.icon(onPressed: () => bloc.add(UserEditorOpened()), icon: const Icon(Icons.refresh), label: Text(context.tr('Retry', 'ลองใหม่'))),
                ],
                if (state.saved) ...[
                  Text(context.tr('User created. Send this link so they can set a password.', 'สร้างผู้ใช้แล้ว ส่งลิงก์นี้ให้ผู้ใช้เพื่อตั้งรหัสผ่าน')),
                  const SizedBox(height: 12),
                ],
                if (state.invite case final invite?) InvitePanel(invite: invite)
                else if (user?.status == UserStatus.pending) ...[
                  const SizedBox(height: 16),
                  Text(context.tr('Creating a new setup link cancels the previous one.', 'สร้างลิงก์ตั้งรหัสผ่านใหม่แล้วลิงก์เดิมจะใช้ไม่ได้')),
                  Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
                    onPressed: state.busy ? null : () => bloc.add(UserInviteRequested()),
                    icon: const Icon(Icons.link),
                    label: Text(context.tr('Create new link', 'สร้างลิงก์ใหม่')),
                  )),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.busy ? null : () => Navigator.of(context).pop(state.saved),
              child: Text(state.saved ? context.tr('Done', 'เสร็จสิ้น') : context.tr('Cancel', 'ยกเลิก')),
            ),
            if (!state.saved) FilledButton(
              onPressed: state.busy || !state.assignmentsLoaded ? null : () => bloc.add(UserSaveRequested()),
              child: state.saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(user == null ? context.tr('Create user', 'สร้างผู้ใช้') : context.tr('Save', 'บันทึก')),
            ),
          ],
        ),
      );
    },
  );
}
