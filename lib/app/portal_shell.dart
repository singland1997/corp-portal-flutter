import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/portal_footer.dart';
import '../core/i18n/locale_cubit.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/data/session_models.dart';
import '../shared/widgets/language_switch.dart';
import '../shared/widgets/theme_switch.dart';
import 'navigation.dart';
import 'theme.dart';

const _desktopBreakpoint = 901.0;

/// Sidebar on wide screens, drawer below 901px (same breakpoint as Angular).
class PortalShell extends StatelessWidget {
  const PortalShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final desktop = constraints.maxWidth >= _desktopBreakpoint;
    final padding = constraints.maxWidth >= 2560 ? 40.0 : desktop ? 32.0 : constraints.maxWidth >= 640 ? 24.0 : 16.0;
    final content = Column(children: [
      _Header(desktop: desktop, location: location),
      Expanded(child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth >= 2560 ? 3200 : 1920),
        child: Padding(padding: EdgeInsets.fromLTRB(padding, padding, padding, 0), child: child),
      ))),
      const PortalFooter(showIntegrationLink: true),
    ]);
    return Scaffold(
      drawer: desktop ? null : Drawer(width: 288, child: _Sidebar(location: location, onNavigated: () => Navigator.of(context).pop())),
      body: desktop
          ? Row(children: [
              SizedBox(width: 248, child: DecoratedBox(decoration: BoxDecoration(border: Border(right: BorderSide(color: context.palette.border))), child: _Sidebar(location: location))),
              Expanded(child: content),
            ])
          : content,
    );
  });
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location, this.onNavigated});
  final String location;
  final VoidCallback? onNavigated;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final current = _currentCorporate(auth);
    final locale = Localizations.localeOf(context);
    Widget section(String title, List<NavigationItem> items) {
      final visible = items.where((i) => i.visibleTo(auth.user?.role)).toList();
      if (visible.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 16, 12, 8), child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: context.palette.muted, fontWeight: FontWeight.w500))),
        for (final item in visible) _NavTile(item: item, selected: location == item.path, onTap: () { onNavigated?.call(); context.go(item.path); }),
      ]);
    }
    return ColoredBox(color: context.palette.surface, child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: () { onNavigated?.call(); context.go('/dashboard'); },
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), child: Row(children: [
          ClipOval(child: Image.asset('assets/images/logo.png', width: 36, height: 36, fit: BoxFit.contain)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Corp Portal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        ])),
      ),
      if (current != null) Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: context.palette.border))),
        child: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: context.palette.subtle, child: Text(_initials(current.displayName(locale)), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.palette.text))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(current.displayName(locale), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            if (current.code != null) Text(current.code!, style: TextStyle(fontSize: 12, color: context.palette.muted)),
          ])),
        ]),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
        section(context.tr('Workspace', 'พื้นที่ทำงาน'), workspaceNavigation),
        section(context.tr('Resources', 'แหล่งข้อมูล'), resourceNavigation),
      ])),
    ])));
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.onTap});
  final NavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Semantics(selected: selected, child: Material(
      color: selected ? context.palette.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8), hoverColor: context.palette.primarySoft, onTap: onTap,
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(item.icon, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(item.label(context), style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
          ]),
        )),
      ),
    )),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.desktop, required this.location});
  final bool desktop;
  final String location;

  void _select(BuildContext context, String id) {
    context.read<AuthBloc>().add(CorporateSelected(id));
    // Pool ids belong to the previous corporate.
    if (location == '/pooling') context.go('/pooling');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth.user;
    final locale = Localizations.localeOf(context);
    final current = _currentCorporate(auth);
    final canSwitch = user != null && user.role != 'corporate' && user.corporates.length > 1;
    final role = switch (user?.role) {
      'admin' => context.tr('Administrator', 'ผู้ดูแลระบบ'),
      'sales' => context.tr('Sales', 'ฝ่ายขาย'),
      _ => context.tr('Corporate user', 'ผู้ใช้องค์กร'),
    };
    return Container(
      constraints: BoxConstraints(minHeight: desktop ? 80 : 64),
      padding: EdgeInsets.symmetric(horizontal: desktop ? 32 : 8, vertical: 8),
      decoration: BoxDecoration(color: context.palette.surface, border: Border(bottom: BorderSide(color: context.palette.border))),
      child: Row(children: [
        if (!desktop) IconButton(tooltip: context.tr('Open navigation', 'เปิดเมนู'), icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer()),
        Expanded(child: Row(children: [
          if (desktop && MediaQuery.sizeOf(context).width >= 1280) ...[
            Text(context.tr('Workspace', 'พื้นที่ทำงาน'), style: TextStyle(fontSize: 12, color: context.palette.muted)),
            Icon(Icons.chevron_right, size: 16, color: context.palette.muted),
          ],
          if (canSwitch) Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: DropdownButtonFormField<String>(
            key: ValueKey(auth.corporateId),
            initialValue: current?.id,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('Select organization', 'เลือกองค์กร')),
            items: [for (final c in user.corporates) DropdownMenuItem(value: c.id, child: Text(c.displayName(locale), overflow: TextOverflow.ellipsis))],
            onChanged: (id) { if (id != null && id != auth.corporateId) _select(context, id); },
          )))
          else if (desktop && current != null) Flexible(child: Text(current.displayName(locale), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.palette.muted))),
        ])),
        const SizedBox(width: 8),
        IconButton(
          tooltip: context.tr('Notifications', 'การแจ้งเตือน'),
          icon: const Icon(Icons.notifications_none),
          onPressed: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
            title: Text(context.tr('You’re all caught up', 'ไม่มีการแจ้งเตือนใหม่')),
            content: Text(context.tr('Notifications will appear here.', 'การแจ้งเตือนจะแสดงที่นี่')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Close', 'ปิด')))],
          )),
        ),
        if (user != null) _AccountMenu(user: user, role: role, desktop: desktop),
      ]),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.user, required this.role, required this.desktop});
  final SessionUser user;
  final String role;
  final bool desktop;
  @override
  Widget build(BuildContext context) => MenuAnchor(
    alignmentOffset: const Offset(-180, 8),
    menuChildren: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(user.email, style: TextStyle(fontSize: 12, color: context.palette.muted)),
        const SizedBox(height: 12),
        const LanguageSwitch(),
        const SizedBox(height: 8),
        const ThemeSwitch(),
      ]))),
      const Divider(height: 1),
      MenuItemButton(
        leadingIcon: const Icon(Icons.logout, size: 18),
        onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
        child: Text(context.tr('Sign out', 'ออกจากระบบ')),
      ),
    ],
    builder: (context, controller, _) => Semantics(button: true, label: context.tr('Account', 'บัญชีผู้ใช้'), child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => controller.isOpen ? controller.close() : controller.open(),
      child: Padding(padding: const EdgeInsets.all(4), child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 18, backgroundColor: context.palette.primarySoft, child: Text(user.initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.palette.text))),
        if (desktop) ...[
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(user.name.split(RegExp(r'\s+')).first, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(role, style: TextStyle(fontSize: 12, color: context.palette.muted)),
          ]),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ])),
    )),
  );
}

CorporateAccount? _currentCorporate(AuthState auth) {
  final corporates = auth.user?.corporates ?? const <CorporateAccount>[];
  for (final c in corporates) { if (c.id == auth.corporateId) return c; }
  return corporates.firstOrNull;
}

String _initials(String name) => name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2).map((s) => s.characters.first).join().toUpperCase();

