import 'package:material_ui/material_ui.dart';
import '../core/i18n/locale_cubit.dart';

/// Menu items; mirrors `core/routing/portal-navigation.ts`.
class NavigationItem {
  const NavigationItem(this.path, this.en, this.th, this.icon, {this.roles});
  final String path, en, th;
  final IconData icon;
  /// Visible only to these roles (null = every role). The API checks access again.
  final Set<String>? roles;
  String label(BuildContext context) => context.tr(en, th);
  bool visibleTo(String? role) => roles == null || (role != null && roles!.contains(role));
}

const workspaceNavigation = <NavigationItem>[
  NavigationItem('/dashboard', 'Dashboard', 'ภาพรวม', Icons.home_outlined),
  NavigationItem('/corporate', 'Inventory', 'ทะเบียนซิมและหมายเลข', Icons.business_outlined),
  NavigationItem('/sim', 'SIM & services', 'ซิมและบริการ', Icons.smartphone_outlined),
  NavigationItem('/pooling', 'Data pooling', 'ดาต้าพูล', Icons.storage_outlined),
  NavigationItem('/users', 'Users', 'ผู้ใช้งาน', Icons.group_outlined, roles: {'admin'}),
  NavigationItem('/billing', 'Billing', 'ใบแจ้งหนี้', Icons.receipt_long_outlined),
  NavigationItem('/reports', 'Reports', 'รายงาน', Icons.description_outlined),
  NavigationItem('/roles', 'Roles & permissions', 'บทบาทและสิทธิ์', Icons.shield_outlined, roles: {'admin'}),
];

const resourceNavigation = <NavigationItem>[
  NavigationItem('/api-docs', 'API documentation', 'เอกสาร API', Icons.code),
];

/// Route path → allowed roles, used by the router guard.
final restrictedRoutes = {
  for (final item in [...workspaceNavigation, ...resourceNavigation])
    if (item.roles != null) item.path: item.roles!,
};
