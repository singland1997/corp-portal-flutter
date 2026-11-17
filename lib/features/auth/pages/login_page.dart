import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/i18n/locale_cubit.dart';
import '../../../shared/widgets/corporate_scope.dart';
import '../../../shared/widgets/required_label.dart';
import '../bloc/auth_bloc.dart';
import 'auth_layout.dart';

String authError(BuildContext context, ApiFailure error) => switch (error.code) {
  'INVALID_CREDENTIALS' || 'UNAUTHORIZED' => context.tr('Incorrect email or password. Please try again.', 'อีเมลหรือรหัสผ่านไม่ถูกต้อง กรุณาลองอีกครั้ง'),
  'RATE_LIMITED' => context.tr('Too many attempts. Please wait a minute and try again.', 'ลองหลายครั้งเกินไป กรุณารอ 1 นาทีแล้วลองใหม่'),
  'TIMEOUT' => context.tr('The request timed out. Please try again.', 'หมดเวลารอการตอบกลับ กรุณาลองอีกครั้ง'),
  'NETWORK_ERROR' => context.tr('Unable to connect to the service.', 'ไม่สามารถเชื่อมต่อบริการได้'),
  'INVALID_RESPONSE' => context.tr('The service returned an unsupported response.', 'รูปแบบข้อมูลจากบริการไม่ถูกต้อง'),
  _ when error.status == 401 => context.tr('Incorrect email or password. Please try again.', 'อีเมลหรือรหัสผ่านไม่ถูกต้อง กรุณาลองอีกครั้ง'),
  _ when error.status == 429 => context.tr('Too many attempts. Please wait a minute and try again.', 'ลองหลายครั้งเกินไป กรุณารอ 1 นาทีแล้วลองใหม่'),
  _ => context.tr('Unable to complete the request. Please try again.', 'ไม่สามารถดำเนินการได้ กรุณาลองอีกครั้ง'),
};

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  void _submit() {
    final bloc = context.read<AuthBloc>();
    if (bloc.state.busy || !_form.currentState!.validate()) return;
    bloc.add(LoginRequested(_email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthBloc, AuthState>(
    listenWhen: (before, after) => before.busy && !after.busy && after.error != null,
    listener: (context, state) => _password.clear(),
    builder: (context, state) => AuthLayout(
      icon: Icons.lock_outline,
      title: context.tr('Welcome to Corp Portal', 'ยินดีต้อนรับสู่ Corp Portal'),
      child: AutofillGroup(child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (state.error case final error?) ...[Notice(authError(context, error), kind: NoticeKind.error), const SizedBox(height: 16)],
        TextFormField(
          controller: _email,
          readOnly: state.busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(label: RequiredLabel(context.tr('Email address', 'อีเมล'))),
          validator: (value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '') ? null : context.tr('Enter a valid email address.', 'กรุณาระบุอีเมลให้ถูกต้อง'),
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: _password,
          readOnly: state.busy,
          autofillHints: const [AutofillHints.password],
          label: RequiredLabel(context.tr('Password', 'รหัสผ่าน')),
          validator: (value) => (value ?? '').isEmpty ? context.tr('Enter your password.', 'กรุณาระบุรหัสผ่าน') : null,
          onSubmitted: _submit,
        ),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.go('/forgot-password'), child: Text(context.tr('Forgot password?', 'ลืมรหัสผ่าน?')))),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: state.busy ? null : _submit,
          child: state.busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(context.tr('Sign in', 'เข้าสู่ระบบ')),
        ),
      ]))),
    ),
  );
}
