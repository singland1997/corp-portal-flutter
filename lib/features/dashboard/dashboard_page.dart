import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../core/api/portal_api.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/business/formatters.dart';
import '../../shared/business/resource_bloc.dart';
import '../../shared/widgets/charts.dart';
import '../../shared/widgets/corporate_scope.dart';
import '../auth/bloc/auth_bloc.dart';
import 'dashboard_models.dart';

typedef _DashboardBloc = ResourceBloc<DashboardSnapshot>;
typedef _DashboardState = ResourceState<DashboardSnapshot>;

/// Home after sign-in: numbers, daily usage and data pool of the current corporate.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => CorporateScope(builder: (context, id) {
    final repository = ApiDashboardRepository(context.read<PortalApi>());
    return BlocProvider(create: (_) => _DashboardBloc(() => repository.load(id))..add(ResourceRequested()), child: const _DashboardView());
  });
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  String _operation(BuildContext context, String key) => switch (key) {
    'simReplace' => context.tr('SIM replacement', 'เปลี่ยนซิม'),
    'simActivate' => context.tr('SIM activation', 'เปิดใช้งานซิม'),
    'simBar' => context.tr('Service restriction', 'ระงับบริการ'),
    _ => key,
  };

  @override
  Widget build(BuildContext context) => BlocBuilder<_DashboardBloc, _DashboardState>(builder: (context, state) {
    if (state.loading || state.data == null) {
      return BusinessFeedback(loading: state.loading, error: state.error, retry: () => context.read<_DashboardBloc>().add(ResourceRequested()));
    }
    final s = state.data!;
    final c = s.numbers;
    final language = Localizations.localeOf(context).languageCode;
    final updated = dateText(s.updatedAt, time: false);
    // Usage figures end at the latest day the CRM has data for, not at the sync date.
    final dataThrough = s.usageThrough == null ? context.tr('no usage data yet', 'ยังไม่มีข้อมูลการใช้งาน') : dateText(s.usageThrough, time: false);
    // The latest data can be older than this month: say so instead of a backwards range.
    final usagePeriod = s.usageThrough == null
        ? dataThrough
        : s.usageThrough!.compareTo(s.periodStart) < 0
            ? '${context.tr('No data this month · latest', 'ยังไม่มีข้อมูลเดือนนี้ · ล่าสุด')} $dataThrough'
            : '${dateText(s.periodStart, time: false)} – $dataThrough';
    final from = DateTime.parse(s.dailyUsageFrom);
    final labels = [for (var i = 0; i < s.dailyUsageGb.length; i++) DateFormat('d MMM', language).format(from.add(Duration(days: i)))];
    final knownDays = s.knownDays;
    final weekTotal = knownDays.isEmpty ? null : knownDays.reduce((a, b) => a + b);
    final used = context.tr('Used', 'ใช้แล้ว');
    final remaining = context.tr('Remaining', 'คงเหลือ');
    final lotId = () {
      final auth = context.read<AuthBloc>().state;
      return auth.user?.corporates.where((x) => x.id == auth.corporateId).firstOrNull?.lotId;
    }();
    // The corporate's CRM quota is the real pool; Portal pools are the fallback.
    final q = s.corporateQuota;
    String tb(double? v) => v == null ? '—' : '${numberText(v)} TB';
    final quotaTitle = q != null ? context.tr('Corporate quota', 'โควตาองค์กร') : context.tr('Pool utilization', 'การใช้ดาต้าพูล');
    final quotaPercent = q != null ? q.usedPercent : s.poolPercent;
    final quotaUsed = q != null ? q.amount(q.used) : tb(s.poolUsedTb);
    final quotaTotal = q != null ? q.amount(q.total) : tb(s.poolQuotaTb);
    final quotaRemaining = q != null ? q.amount(q.remaining) : tb(s.poolRemainingTb);
    final List<double> ring = q != null && q.used != null && q.total != null
        ? [q.used!, (q.total! - q.used!).clamp(0, double.infinity).toDouble()]
        : s.poolKnown ? [s.poolUsedTb!, (s.poolRemainingTb!).clamp(0, double.infinity).toDouble()] : const [];
    final over = q?.overQuota ?? false;

    final stats = [
      _Stat(context.tr('Total mobile numbers', 'หมายเลขทั้งหมด'), numberText(c.total), c.statusUnknown ? context.tr('Status unknown', 'ไม่ทราบสถานะ') : '${numberText(c.active)} ${context.tr('Active', 'ใช้งานอยู่')}', Icons.smartphone_outlined),
      _Stat(context.tr('Active', 'ใช้งานอยู่'), c.statusUnknown ? '—' : numberText(c.active), ['${numberText(c.inactive)} ${context.tr('Inactive', 'ไม่ใช้งาน')}', '${numberText(c.suspended)} ${context.tr('Suspended', 'ระงับ')}', if (c.terminated > 0) '${numberText(c.terminated)} ${context.tr('Terminated', 'ยกเลิกแล้ว')}', if (c.unknown > 0) '${numberText(c.unknown)} ${context.tr('unknown', 'ไม่ทราบสถานะ')}'].join(' · '), Icons.check_circle_outline),
      // The API totals the current month of the synced window (periodStart → sync date).
      _Stat(context.tr('Total data usage', 'ปริมาณดาต้ารวม'), s.totalUsageTb == null ? '—' : '${numberText(s.totalUsageTb)} TB', usagePeriod, Icons.show_chart),
      _Stat(quotaTitle, quotaPercent == null ? '—' : '$quotaPercent%', '$quotaUsed / $quotaTotal', Icons.storage_outlined),
    ];

    final trend = BusinessCard(title: context.tr('Data usage trend', 'แนวโน้มการใช้ดาต้า'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(context.tr('Daily usage across all active numbers', 'การใช้ดาต้ารายวันของหมายเลขที่ใช้งานอยู่'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      // Days without data are gaps; a week with no data shows the empty axes and grid.
      UsageLineChart(
        values: s.dailyUsageGb, labels: labels,
        semanticLabel: '${context.tr('Data usage trend', 'แนวโน้มการใช้ดาต้า')}: ${s.dailyUsageGb.map((v) => v == null ? context.tr('Unknown', 'ไม่ทราบ') : '${numberText(v)} GB').join(', ')}',
      ),
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
        Text('${context.tr('Data through', 'ข้อมูลถึง')} $dataThrough', style: TextStyle(fontSize: 12, color: context.palette.muted)),
        Text('${weekTotal == null ? '—' : numberText(weekTotal)} GB · ${knownDays.length}/${s.dailyUsageGb.length} ${context.tr('days', 'วัน')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    ]));

    final danger = Theme.of(context).colorScheme.error;
    final pool = BusinessCard(
      title: q != null ? context.tr('Corporate quota', 'โควตาองค์กร') : context.tr('Shared data pool', 'ดาต้าพูลส่วนกลาง'),
      action: TextButton.icon(onPressed: () => context.go('/pooling'), iconAlignment: IconAlignment.end, icon: const Icon(Icons.arrow_forward, size: 16), label: Text(context.tr('Details', 'รายละเอียด'))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (q != null) Text('${context.tr('Valid until', 'ใช้ได้ถึง')} ${dateText(q.expiresAt, time: false)} · ${numberText(q.activeMembers)} ${context.tr('member numbers', 'เบอร์ที่ใช้ร่วม')}', style: Theme.of(context).textTheme.bodySmall)
        else if (lotId != null) Text(lotId, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        // Unknown quota draws the empty ring (never a fake 0%); over quota fills it in the error color.
        Center(child: DonutChart(
          size: 210, thickness: .11,
          values: ring,
          colors: [over ? danger : PortalColors.primary, context.palette.subtle],
          semanticLabel: ring.isEmpty
              ? '$quotaTitle: ${context.tr('Unknown', 'ไม่ทราบ')}'
              : '$used $quotaUsed; $remaining $quotaRemaining',
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${quotaPercent ?? '—'}%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: over ? danger : null)),
            Text(used, style: TextStyle(fontSize: 12, color: context.palette.muted)),
          ]),
        )),
        const SizedBox(height: 16),
        if (over) ...[
          Notice(context.tr('Usage is above the corporate quota.', 'ใช้เกินโควตาองค์กรแล้ว'), kind: NoticeKind.error),
          const SizedBox(height: 12),
        ],
        _Legend(color: over ? danger : PortalColors.primary, label: used, value: '$quotaUsed / $quotaTotal'),
        const SizedBox(height: 8),
        _Legend(color: context.palette.border, label: remaining, value: quotaRemaining),
      ]),
    );

    final activity = BusinessCard(
      title: context.tr('Recent SIM activity', 'รายการซิมล่าสุด'),
      action: TextButton.icon(onPressed: () => context.go('/corporate'), iconAlignment: IconAlignment.end, icon: const Icon(Icons.arrow_forward, size: 16), label: Text(context.tr('View all numbers', 'ดูหมายเลขทั้งหมด'))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('Latest service changes in your corporate account', 'การเปลี่ยนแปลงบริการล่าสุดในองค์กร'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (!s.activityComplete) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(context.tr('Some source activity has an unverified date format and is not listed.', 'กิจกรรมบางรายการในระบบต้นทางมีรูปแบบวันที่ที่ยังไม่ยืนยัน จึงไม่แสดง'), style: TextStyle(fontSize: 12, color: context.palette.muted))),
        if (s.activity.isEmpty) const BusinessFeedback()
        else for (final (index, item) in s.activity.indexed) ...[
          if (index > 0) const Divider(height: 1),
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: context.palette.subtle, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.history, size: 18, color: context.palette.muted)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_operation(context, item.operation), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('${item.mobile ?? '—'} · ${dateText(item.time)}', style: TextStyle(fontSize: 12, color: context.palette.muted)),
            ])),
            BusinessStatus(item.status),
          ])),
        ],
      ]),
    );

    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1280;
      final statColumns = constraints.maxWidth >= 1280 ? 4 : constraints.maxWidth >= 400 ? 2 : 1;
      final statWidth = (constraints.maxWidth - (statColumns - 1) * 16) / statColumns;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(title: context.tr('Dashboard', 'ภาพรวม'), actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: context.palette.surface, border: Border.all(color: context.palette.border), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today_outlined, size: 14), const SizedBox(width: 8), Text(updated, style: const TextStyle(fontSize: 12))]),
          ),
        ]),
        const SizedBox(height: 20),
        Wrap(spacing: 16, runSpacing: 16, children: [for (final stat in stats) SizedBox(width: statWidth, child: stat)]),
        const SizedBox(height: 20),
        if (wide) IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 18, child: trend), const SizedBox(width: 24), Expanded(flex: 10, child: pool)]))
        else ...[trend, const SizedBox(height: 16), pool],
        const SizedBox(height: 20),
        activity,
      ]);
    }));
  });
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.hint, this.icon);
  final String label, value, hint;
  final IconData icon;
  @override
  Widget build(BuildContext context) => BusinessCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: context.palette.muted)),
      const SizedBox(height: 10),
      Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(hint, style: TextStyle(fontSize: 12, color: context.palette.muted)),
    ])),
    Container(width: 36, height: 36, decoration: BoxDecoration(color: context.palette.primarySoft, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18)),
  ]));
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});
  final Color color;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 12)),
    const Spacer(),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}
