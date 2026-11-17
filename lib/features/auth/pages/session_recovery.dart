import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/i18n/locale_cubit.dart';
import '../bloc/auth_bloc.dart';
import 'auth_layout.dart';

/// Keeps the requested route while session restoration is temporarily unavailable.
class SessionRecovery extends StatelessWidget {
  const SessionRecovery({super.key, required this.auth});
  final AuthState auth;
  @override
  Widget build(BuildContext context) => AuthLayout(
    icon: Icons.cloud_off_outlined,
    title: context.tr('Connection interrupted', 'การเชื่อมต่อขัดข้อง'),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(context.tr('Your saved session has been kept. Reconnect to continue.', 'เก็บเซสชันเดิมไว้แล้ว ลองเชื่อมต่อใหม่เพื่อใช้งานต่อ')),
      const SizedBox(height: 16),
      RecoveryActions(auth: auth),
    ]),
  );
}

class RecoveryActions extends StatelessWidget {
  const RecoveryActions({super.key, required this.auth});
  final AuthState auth;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
    FilledButton.icon(
      onPressed: auth.busy ? null : () => context.read<AuthBloc>().add(SessionRetryRequested()),
      icon: const Icon(Icons.refresh),
      label: Text(context.tr('Reconnect', 'เชื่อมต่อใหม่')),
    ),
    TextButton(
      onPressed: auth.busy ? null : () => context.read<AuthBloc>().add(LogoutRequested()),
      child: Text(context.tr('Sign out', 'ออกจากระบบ')),
    ),
  ]);
}
