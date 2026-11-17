import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/app_config.dart';
import '../../../core/i18n/locale_cubit.dart';
import '../data/user_models.dart';

/// Setup credentials live only in the open dialog and are never persisted.
class InvitePanel extends StatefulWidget {
  const InvitePanel({super.key, required this.invite});
  final UserInvite invite;
  @override
  State<InvitePanel> createState() => _InvitePanelState();
}

class _InvitePanelState extends State<InvitePanel> {
  bool _copied = false;

  @override
  void didUpdateWidget(covariant InvitePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invite.token != widget.invite.token) _copied = false;
  }

  @override
  Widget build(BuildContext context) {
    final configured = context.read<AppConfig>().publicWebUrl;
    final base = configured.isNotEmpty ? Uri.tryParse(configured) : kIsWeb ? Uri.base : null;
    final validBase = base != null && ['http', 'https'].contains(base.scheme) && base.hasAuthority;
    // Flutter uses hash routing unless its router explicitly enables path strategy.
    final value = validBase
        ? base.replace(path: '/', query: '', fragment: '/set-password?token=${Uri.encodeComponent(widget.invite.token)}').toString()
        : widget.invite.token;
    final expires = widget.invite.expiresAt.toLocal();
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(validBase ? context.tr('Set-password link', 'ลิงก์ตั้งรหัสผ่าน') : context.tr('Setup token', 'รหัสตั้งรหัสผ่าน'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SelectableText(value),
          const SizedBox(height: 8),
          Text('${context.tr('One use. Expires:', 'ใช้ได้ครั้งเดียว หมดอายุ:')} ${MaterialLocalizations.of(context).formatMediumDate(expires)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(expires))}'),
          if (!validBase) Text(context.tr('Configure PORTAL_WEB_URL to generate a website link.', 'กำหนด PORTAL_WEB_URL เพื่อสร้างลิงก์เว็บไซต์')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: value));
                if (mounted) setState(() => _copied = true);
              } catch (_) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Select the text to copy it manually.', 'เลือกข้อความแล้วคัดลอกด้วยตนเอง'))));
              }
            },
            icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
            label: Text(_copied ? context.tr('Copied', 'คัดลอกแล้ว') : context.tr('Copy', 'คัดลอก')),
          ),
        ]),
      ),
    );
  }
}
