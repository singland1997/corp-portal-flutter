import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/locale_cubit.dart';
import 'auth_layout.dart';

/// Self-service reset is not available; users contact their administrator.
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});
  @override
  Widget build(BuildContext context) => AuthLayout(
    icon: Icons.key_outlined,
    title: context.tr('Forgot password?', 'ลืมรหัสผ่าน?'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        context.tr('Contact your corporate administrator to reset your password and restore access to your account.', 'กรุณาติดต่อผู้ดูแลระบบขององค์กรเพื่อรีเซ็ตรหัสผ่านและกลับเข้าใช้งานบัญชีของคุณ'),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      FilledButton(onPressed: () => context.go('/login'), child: Text(context.tr('Back to sign in', 'กลับไปเข้าสู่ระบบ'))),
    ]),
  );
}
