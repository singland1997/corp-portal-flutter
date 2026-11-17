import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../business/business_widgets.dart';
import '../../app/theme.dart';

/// Rebuilds [builder] from scratch when the selected corporate changes, so page blocs
/// never mix data from two corporates (Angular `corporateResource`).
class CorporateScope extends StatelessWidget {
  const CorporateScope({super.key, required this.builder});
  final Widget Function(BuildContext context, String corporateId) builder;
  @override
  Widget build(BuildContext context) => BlocSelector<AuthBloc, AuthState, String?>(
    selector: (state) => state.corporateId,
    builder: (context, id) => id == null || id.isEmpty
        ? const BusinessFeedback()
        : KeyedSubtree(key: ValueKey(id), child: Builder(builder: (context) => builder(context, id))),
  );
}

/// Page title with optional actions, wrapping on narrow screens.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.actions = const []});
  final String title;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
      if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
    ],
  );
}

enum NoticeKind { success, info, warning, error }

/// Inline message (PrimeNG `p-message`).
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.kind = NoticeKind.info, this.title});
  final String text;
  final String? title;
  final NoticeKind kind;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Info uses the brand yellow; the other kinds keep their meaning colours.
    if (kind == NoticeKind.info) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: PortalColors.primary.withValues(alpha: .6))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 20, color: p.link),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(title!, style: TextStyle(fontWeight: FontWeight.w600, color: p.text))),
            Text(text, style: TextStyle(color: p.text)),
          ])),
        ]),
      );
    }
    final (color, icon) = switch (kind) {
      NoticeKind.success => (Colors.green, Icons.check_circle_outline),
      NoticeKind.warning => (Colors.orange, Icons.warning_amber_outlined),
      _ => (Colors.red, Icons.error_outline),
    };
    final dark = context.isDark;
    return Semantics(liveRegion: kind == NoticeKind.error || kind == NoticeKind.success, child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: context.isDark ? .16 : .08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: .3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: dark ? color.shade200 : color.shade800),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(title!, style: TextStyle(fontWeight: FontWeight.w600, color: dark ? color.shade100 : color.shade900))),
          Text(text, style: TextStyle(color: dark ? color.shade100 : color.shade900)),
        ])),
      ]),
    ));
  }
}
