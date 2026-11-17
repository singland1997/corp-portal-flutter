import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/locale_cubit.dart';
import '../../../shared/widgets/corporate_scope.dart';
import '../../../shared/widgets/required_label.dart';
import '../bloc/set_password_cubit.dart';
import '../data/session_repository.dart';
import 'auth_layout.dart';

/// Opened from `/set-password?token=...`; on success the account becomes Active.
class SetPasswordPage extends StatelessWidget {
  const SetPasswordPage({super.key, required this.token});
  final String token;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SetPasswordCubit(context.read<SessionRepository>(), token),
    child: const _SetPasswordView(),
  );
}

class _SetPasswordView extends StatefulWidget {
  const _SetPasswordView();
  @override
  State<_SetPasswordView> createState() => _SetPasswordViewState();
}

class _SetPasswordViewState extends State<_SetPasswordView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }

  String _message(SetPasswordProblem problem) => switch (problem) {
    SetPasswordProblem.missingLink => context.tr('This link is incomplete. Open the full link from your administrator.', 'ลิงก์ไม่ครบ กรุณาเปิดลิงก์เต็มที่ได้รับจากผู้ดูแลระบบ'),
    SetPasswordProblem.tooShort => context.tr('The password must be at least 12 characters.', 'รหัสผ่านต้องมีอย่างน้อย 12 ตัวอักษร'),
    SetPasswordProblem.mismatch => context.tr('The passwords do not match.', 'รหัสผ่านทั้งสองช่องไม่ตรงกัน'),
    SetPasswordProblem.invalidLink => context.tr('This link is invalid, already used, or expired. Ask your administrator for a new one.', 'ลิงก์นี้ไม่ถูกต้อง ถูกใช้ไปแล้ว หรือหมดอายุ กรุณาขอลิงก์ใหม่จากผู้ดูแลระบบ'),
    SetPasswordProblem.tooManyAttempts => context.tr('Too many attempts. Please wait a minute and try again.', 'ลองหลายครั้งเกินไป กรุณารอ 1 นาทีแล้วลองใหม่'),
    SetPasswordProblem.failed => context.tr('Unable to complete the request. Please try again.', 'ไม่สามารถดำเนินการได้ กรุณาลองอีกครั้ง'),
  };

  @override
  Widget build(BuildContext context) => BlocConsumer<SetPasswordCubit, SetPasswordState>(
    listenWhen: (before, after) => !before.done && after.done,
    listener: (context, state) { _password.clear(); _confirm.clear(); },
    builder: (context, state) {
      final cubit = context.read<SetPasswordCubit>();
      void submit() => cubit.submit(_password.text, _confirm.text);
      if (state.done) {
        return AuthLayout(icon: Icons.key_outlined, title: context.tr('Password set', 'ตั้งรหัสผ่านเรียบร้อย'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('Your account is active. You can now sign in with your email and new password.', 'บัญชีของคุณพร้อมใช้งานแล้ว เข้าสู่ระบบด้วยอีเมลและรหัสผ่านใหม่ได้เลย'), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => context.go('/login'), child: Text(context.tr('Go to sign in', 'ไปหน้าเข้าสู่ระบบ'))),
        ]));
      }
      return AuthLayout(icon: Icons.key_outlined, title: context.tr('Set your password', 'ตั้งรหัสผ่าน'), child: AutofillGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('Create a password to activate your Corp Portal account.', 'ตั้งรหัสผ่านเพื่อเปิดใช้งานบัญชี Corp Portal ของคุณ')),
        const SizedBox(height: 16),
        if (cubit.token.isEmpty) ...[Notice(_message(SetPasswordProblem.missingLink), kind: NoticeKind.warning), const SizedBox(height: 16)],
        if (state.problem case final problem? when !(problem == SetPasswordProblem.missingLink && cubit.token.isEmpty)) ...[Notice(_message(problem), kind: NoticeKind.error), const SizedBox(height: 16)],
        PasswordField(
          controller: _password, readOnly: state.busy,
          autofillHints: const [AutofillHints.newPassword],
          label: RequiredLabel(context.tr('New password', 'รหัสผ่านใหม่')),
          helperText: context.tr('At least 12 characters.', 'อย่างน้อย 12 ตัวอักษร'),
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: _confirm, readOnly: state.busy,
          autofillHints: const [AutofillHints.newPassword],
          label: RequiredLabel(context.tr('Confirm password', 'ยืนยันรหัสผ่าน')),
          onSubmitted: submit,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: state.busy || cubit.token.isEmpty ? null : submit,
          child: state.busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(context.tr('Set password', 'ตั้งรหัสผ่าน')),
        ),
      ])));
    },
  );
}
