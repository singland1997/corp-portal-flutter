import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/i18n/locale_cubit.dart';

/// One version/environment display for guest and authenticated pages.
class PortalFooter extends StatelessWidget {
  const PortalFooter({super.key, this.showIntegrationLink = false});
  final bool showIntegrationLink;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: showIntegrationLink
        ? BoxDecoration(border: Border(top: BorderSide(color: context.palette.border)))
        : null,
    child: Wrap(
      alignment: showIntegrationLink ? WrapAlignment.spaceBetween : WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(
          '© ${DateTime.now().year} ${context.tr('Corp Portal · Corporate connectivity', 'Corp Portal · บริการสื่อสารสำหรับองค์กร')} · ${context.read<AppConfig>().versionLabel}',
          textAlign: showIntegrationLink ? TextAlign.start : TextAlign.center,
          style: TextStyle(fontSize: 12, color: context.palette.muted),
        ),
        if (showIntegrationLink) TextButton.icon(
          onPressed: () => context.go('/api-docs'),
          icon: const Icon(Icons.north_east, size: 14),
          label: Text(context.tr('Integration guide', 'คู่มือการเชื่อมต่อ')),
        ),
      ],
    ),
  );
}
