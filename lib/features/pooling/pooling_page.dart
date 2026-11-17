import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/api/portal_api.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/business_table.dart';
import '../../shared/business/paged_table.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/business/formatters.dart';
import '../../shared/download/save_text_file.dart';
import '../../shared/widgets/charts.dart';
import '../../shared/widgets/corporate_scope.dart';
import '../auth/bloc/auth_bloc.dart';
import '../reports/report_format.dart' show csvCell;
import 'corporate_quota.dart';
import 'pooling_cubit.dart';
import 'pooling_dialogs.dart';
import 'pooling_models.dart';
import 'pooling_repository.dart';
import 'pooling_text.dart';

// Same value as the API's department filter for members without a department.
const _noDepartment = '__none__';

/// Two modes from `?pool=<id>`: overview (list + selected pool) or the pool's details.
class PoolingPage extends StatelessWidget {
  const PoolingPage({super.key, this.poolId});
  final String? poolId;
  @override
  Widget build(BuildContext context) => CorporateScope(builder: (context, id) => BlocProvider(
    create: (_) => PoolingCubit(ApiPoolingRepository(context.read<PortalApi>()), id)..load(),
    child: _PoolingView(poolId: poolId),
  ));
}

class _PoolingView extends StatefulWidget {
  const _PoolingView({this.poolId});
  final String? poolId;
  @override
  State<_PoolingView> createState() => _PoolingViewState();
}

class _PoolingViewState extends State<_PoolingView> {
  String? _selected;
  String _statusFilter = 'all', _department = 'all', _type = 'all';
  DateTime? _from, _to;
  String? _notice;
  // From the latest transactions page (export button, optional source-quantity column).
  int _transactionTotal = 0;
  bool _showAfterQuantity = false;

  bool get _detail => widget.poolId != null;

  @override
  void didUpdateWidget(covariant _PoolingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poolId != widget.poolId) _resetPoolFilters();
  }

  void _resetPoolFilters() { _from = null; _to = null; _type = 'all'; _department = 'all'; }

  void _select(String id) => setState(() { _selected = id; _resetPoolFilters(); _notice = null; });

  String _corporateName() {
    final auth = context.read<AuthBloc>().state;
    final corporate = auth.user?.corporates.where((c) => c.id == auth.corporateId).firstOrNull;
    return corporate?.displayName(Localizations.localeOf(context)) ?? '';
  }

  Future<void> _openForm([DataPool? pool]) async {
    final cubit = context.read<PoolingCubit>();
    final saved = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => BlocProvider.value(value: cubit, child: PoolFormDialog(pool: pool, corporateName: _corporateName())));
    if (saved == true && mounted) setState(() => _notice = 'saved');
  }

  Future<void> _openQuota(DataPool pool, String direction) async {
    final cubit = context.read<PoolingCubit>();
    final adjusted = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => BlocProvider.value(value: cubit, child: QuotaDialog(poolId: pool.id, direction: direction)));
    if (adjusted == true && mounted) setState(() { _from = null; _to = null; _type = 'all'; _notice = 'adjusted'; });
  }

  static String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// CSV holds every matching transaction, not only the visible page.
  Future<void> _export(DataPool pool) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.tr('Unable to save the file.', 'ไม่สามารถบันทึกไฟล์ได้');
    final cubit = context.read<PoolingCubit>();
    final List<PoolTransaction> rows;
    try {
      rows = (await cubit.repository.allTransactions(cubit.corporateId)).where((t) =>
        t.poolId == pool.id && matchesPoolDateRange(t.occurredAt, _from, _to) && (_type == 'all' || t.type == _type)).toList()
        ..sort((a, b) => (b.occurredAt ?? '').compareTo(a.occurredAt ?? ''));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return;
    }
    if (!mounted) return;
    final lines = <List<String>>[
      [context.tr('Date / time (ICT)', 'วันที่ / เวลา (ไทย)'), context.tr('Type', 'ประเภทรายการ'), context.tr('Change (MB)', 'จำนวนที่ปรับ (MB)'), context.tr('Total after change (MB)', 'โควตาหลังปรับ (MB)'), context.tr('Remaining after change (MB)', 'คงเหลือหลังปรับ (MB)'), context.tr('Performed by', 'ผู้ทำรายการ'), context.tr('Reason', 'เหตุผล')],
      for (final t in rows) [dateText(t.occurredAt), transactionType(context, t.type), _raw(t.amountMb), _raw(t.totalAfterMb), _raw(t.remainingAfterMb), t.performedBy ?? '', t.reason ?? ''],
    ];
    final csv = '﻿${lines.map((l) => l.map(csvCell).join(',')).join('\r\n')}\r\n';
    try { await saveTextFile('pool-transactions-${pool.id}.csv', csv); }
    catch (_) { messenger.showSnackBar(SnackBar(content: Text(failed))); }
  }

  static String _raw(double? value) => value == null ? '' : (value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value');

  @override
  Widget build(BuildContext context) => BlocBuilder<PoolingCubit, PoolingState>(builder: (context, state) {
    final cubit = context.read<PoolingCubit>();
    if (state.data == null) return BusinessFeedback(loading: state.loading, error: state.error, retry: cubit.load);
    final data = state.data!;
    final pools = data.pools;
    final poolId = widget.poolId ?? _selected ?? pools.firstOrNull?.id;
    final pool = pools.where((p) => p.id == poolId).firstOrNull;

    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title: _detail ? context.tr('Pool details', 'รายละเอียดพูล') : context.tr('Shared data pool', 'ดาต้าพูลร่วม'), actions: [
        if (_detail) OutlinedButton.icon(onPressed: () => context.go('/pooling'), icon: const Icon(Icons.arrow_back), label: Text(context.tr('Back to overview', 'กลับหน้าภาพรวม'))),
        FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: Text(context.tr('Create pool', 'สร้างพูล'))),
      ]),
      const SizedBox(height: 20),
      if (state.error != null) ...[BusinessFeedback(error: state.error, retry: cubit.load), const SizedBox(height: 16)],
      if (_notice != null) ...[Notice(_notice == 'saved' ? context.tr('Pool saved.', 'บันทึกพูลแล้ว') : context.tr('Quota updated. Transaction recorded.', 'ปรับโควตาและบันทึกประวัติรายการแล้ว'), kind: NoticeKind.success), const SizedBox(height: 16)],
      if (pool != null) ..._poolSections(context, data, pool)
      else if (pools.isNotEmpty || _detail) ...[
        Notice(poolErrorText(context, PoolError.poolMissing), kind: NoticeKind.error),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: () => context.go('/pooling'), child: Text(context.tr('Back to overview', 'กลับหน้าภาพรวม')))),
        const SizedBox(height: 16),
      ],
      // The corporate's own CRM quota comes first: it exists without any Portal pool.
      if (!_detail) ...[
        CorporateQuotaSection(key: ObjectKey(data), repository: CorporateQuotaRepository(context.read<PortalApi>()), corporateId: cubit.corporateId),
        const SizedBox(height: 16),
      ],
      if (!_detail) BusinessCard(title: context.tr('Data pools', 'รายการดาต้าพูล'), child: RemoteTable<DataPool>(
        // A new snapshot (after a save) reloads the page from the API.
        key: ObjectKey(data),
        load: (q) => cubit.repository.pools(cubit.corporateId, q),
        initialQuery: PageQuery(sort: 'name', filters: {if (_statusFilter != 'all') 'status': _statusFilter}),
        id: (p) => p.id,
        filters: SizedBox(width: 180, child: DropdownButtonFormField<String>(
          initialValue: _statusFilter, isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('Status', 'สถานะ')),
          items: [
            DropdownMenuItem(value: 'all', child: Text(context.tr('All statuses', 'ทุกสถานะ'))),
            for (final s in ['active', 'inactive']) DropdownMenuItem(value: s, child: Text(poolStatusText(context, s))),
          ],
          onChanged: (v) => setState(() => _statusFilter = v!),
        )),
        columns: [
          RemoteColumn(context.tr('Pool name', 'ชื่อพูล'), (p) => Text(p.name), sortKey: 'name'),
          RemoteColumn(context.tr('Corporate', 'บริษัท'), (p) => Text(p.corporate), sortKey: 'corporate'),
          RemoteColumn(context.tr('Total quota', 'โควตารวม'), (p) => Text(poolData(p.quotaMb)), sortKey: 'quotaMb'),
          RemoteColumn(context.tr('Remaining data', 'ข้อมูลคงเหลือ'), (p) => Text(poolData(p.remainingMb))),
          RemoteColumn(context.tr('Status', 'สถานะ'), (p) => BusinessStatus(p.status), sortKey: 'status'),
        ],
        actions: (p) => Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: context.tr('Pool details', 'รายละเอียดพูล'), icon: const Icon(Icons.visibility_outlined), onPressed: () { _select(p.id); context.go('/pooling?pool=${Uri.encodeQueryComponent(p.id)}'); }),
          IconButton(tooltip: context.tr('Edit pool', 'แก้ไขพูล'), icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(p)),
        ]),
      )),
    ]));
  });

  List<Widget> _poolSections(BuildContext context, PoolingSnapshot data, DataPool pool) {
    final remaining = pool.remainingMb;
    final overQuota = (remaining ?? 0) < 0;
    final canIncrease = pool.status == 'active' && data.quotaAdjust && remaining != null;
    final canDecrease = canIncrease && remaining > 0;
    final members = data.members.where((m) => m.poolId == pool.id).toList();
    final departments = members.map((m) => m.department).whereType<String>().where((d) => d.isNotEmpty).toSet().toList()..sort();
    final invalidDates = _from != null && _to != null && _from!.isAfter(_to!);
    final transactionFilters = {
      'pool': pool.id,
      if (_type != 'all') 'type': _type,
      if (_from != null) 'from': _isoDate(_from!),
      if (_to != null) 'to': _isoDate(_to!),
    };
    final inventory = data.inventory.where((i) => i.poolId == pool.id).toList();
    final hasQuota = (pool.quotaMb ?? 0) > 0 || (pool.usedMb ?? 0) > 0;
    // Unknown usage is not counted as 0.
    final usage = [
      for (final d in departments) (d, members.where((m) => m.department == d && m.usedMb != null).fold<double>(0, (sum, m) => sum + m.usedMb!)),
    ].where((d) => d.$2 > 0).toList();
    final used = context.tr('Used data', 'ใช้ไปแล้ว');
    final remainingLabel = context.tr('Remaining data', 'ข้อมูลคงเหลือ');

    final overview = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: context.palette.primarySoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: PortalColors.primary)),
      child: DefaultTextStyle.merge(style: TextStyle(color: context.palette.text), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('Current snapshot', 'ข้อมูลปัจจุบัน').toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: context.palette.link)),
        const SizedBox(height: 8),
        Text(context.tr('Current usage', 'การใช้งานปัจจุบัน'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        // No quota or unknown quantities draw the empty ring.
        Row(children: [
          DonutChart(
            size: 128,
            values: !hasQuota || pool.usedMb == null || pool.quotaMb == null ? const [] : [pool.usedMb!.clamp(0, pool.quotaMb!), (remaining ?? 0).clamp(0, double.infinity), (-(remaining ?? 0)).clamp(0, double.infinity)],
            colors: [PortalColors.primaryActive, context.palette.surface, PortalColors.danger],
            semanticLabel: '$used ${poolData(pool.usedMb)}; $remainingLabel ${poolData(remaining)}',
          ),
          const SizedBox(width: 24),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pool.percent == null ? '—' : '${pool.percent}%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
            Text(hasQuota ? used : context.tr('No quota allocated', 'ยังไม่ได้จัดสรรโควตา'), style: TextStyle(fontSize: 13, color: context.palette.muted)),
          ]),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          for (final (label, value, red) in [(used, poolData(pool.usedMb), false), (remainingLabel, poolData(remaining), overQuota), (context.tr('Total quota', 'โควตารวม'), poolData(pool.quotaMb), false)])
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: red ? Theme.of(context).colorScheme.error : context.palette.text)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: context.palette.muted)),
            ])),
        ]),
      ])),
    );

    final byDepartment = BusinessCard(title: context.tr('Usage by department', 'การใช้งานตามแผนก'), child: usage.isEmpty
        ? Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Text(context.tr('No department usage available.', 'ยังไม่มีข้อมูลการใช้งานตามแผนก'), style: TextStyle(color: context.palette.muted)))
        : Column(children: [
            for (final (key, value) in usage) Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Expanded(child: Text(departmentText(context, key))), Text(poolData(value), style: const TextStyle(fontWeight: FontWeight.w600))]),
              const SizedBox(height: 8),
              Semantics(label: departmentText(context, key), child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                minHeight: 8, color: PortalColors.primary,
                value: (pool.usedMb ?? 0) > 0 ? (value / pool.usedMb!).clamp(0, 1) : 0,
              ))),
            ])),
          ]));

    return [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (!_detail) SizedBox(width: 240, child: DropdownButtonFormField<String>(
            key: ValueKey(pool.id), initialValue: pool.id, isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('Pool', 'พูล')),
            items: [for (final p in data.pools) DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))],
            onChanged: (id) { if (id != null) _select(id); },
          )) else Text(pool.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          BusinessStatus(pool.status),
          Text('${pool.corporate} · ${pool.lot ?? '—'}', style: TextStyle(fontSize: 13, color: context.palette.muted)),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () => _openForm(pool), icon: const Icon(Icons.edit_outlined), label: Text(context.tr('Edit pool', 'แก้ไขพูล'))),
          FilledButton.icon(onPressed: canIncrease ? () => _openQuota(pool, 'increase') : null, icon: const Icon(Icons.add), label: Text(context.tr('Increase quota', 'เพิ่มโควตา'))),
          OutlinedButton.icon(onPressed: canDecrease ? () => _openQuota(pool, 'decrease') : null, icon: const Icon(Icons.remove), label: Text(context.tr('Decrease quota', 'ลดโควตา'))),
        ]),
      ]),
      const SizedBox(height: 16),
      if (pool.status == 'inactive') ...[Notice(context.tr('An inactive pool cannot receive quota changes.', 'พูลที่ไม่ใช้งานจะไม่สามารถปรับโควตาได้')), const SizedBox(height: 12)],
      if (!data.quotaAdjust) ...[Notice(context.tr('This action needs the provisioning API connection, which is not configured. No change was made.', 'รายการนี้ต้องเชื่อมต่อ provisioning API ซึ่งยังไม่ได้ตั้งค่า ยังไม่มีการเปลี่ยนแปลงข้อมูล')), const SizedBox(height: 12)],
      if (pool.sourceState == 'unlinked') ...[Notice(context.tr('No source quota bucket is linked to this pool yet.', 'ยังไม่มีบัคเก็ตโควตาจากระบบต้นทางเชื่อมกับพูลนี้')), const SizedBox(height: 12)]
      else if (pool.sourceState == 'partial') ...[Notice(context.tr('Some linked buckets are unverified or use an unmapped unit, so the quota is unknown.', 'บัคเก็ตที่เชื่อมบางรายการยังไม่ได้ยืนยันหรือใช้หน่วยที่ยังไม่กำหนด จึงยังไม่ทราบโควตา'), kind: NoticeKind.warning), const SizedBox(height: 12)],
      if (overQuota) ...[Notice(context.tr('Remaining data is negative. The chart shows used data within quota and overage separately.', 'ยอดคงเหลือติดลบ กราฟแยกข้อมูลที่ใช้ภายในโควตาและส่วนที่เกินออกจากกัน'), title: context.tr('Usage exceeds quota', 'ใช้งานเกินโควตา'), kind: NoticeKind.warning), const SizedBox(height: 12)],
      LayoutBuilder(builder: (context, constraints) => constraints.maxWidth >= 1024
          ? IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 2, child: overview), const SizedBox(width: 24), Expanded(flex: 3, child: byDepartment)]))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [overview, const SizedBox(height: 16), byDepartment])),
      const SizedBox(height: 16),
      if (_detail) ...[
        BusinessCard(title: context.tr('Pool details', 'รายละเอียดพูล'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 32, children: [
            for (final item in [
              (context.tr('Pool', 'พูล'), pool.id), (context.tr('Corporate lot', 'ล็อตของบริษัท'), pool.lot ?? '—'),
              (context.tr('Pool members', 'สมาชิกในพูล'), numberText(members.length)),
              (context.tr('Created on', 'วันที่สร้าง'), '${dateText(pool.createdAt)} · ${pool.createdBy}'),
              (context.tr('Updated on', 'วันที่แก้ไข'), '${dateText(pool.updatedAt)} · ${pool.updatedBy}'),
            ]) SizedBox(width: 260, child: FieldDetails(items: [item])),
          ]),
          OutlinedButton.icon(onPressed: () => _showInventory(context, inventory), icon: const Icon(Icons.list), label: Text(context.tr('Current inventory', 'รายการ Inventory ปัจจุบัน'))),
        ])),
        const SizedBox(height: 16),
      ],
      BusinessCard(title: context.tr('Pool members', 'สมาชิกในพูล'), child: RemoteTable<PoolMember>(
        key: ObjectKey(data),
        load: (q) => context.read<PoolingCubit>().repository.members(context.read<PoolingCubit>().corporateId, q),
        initialQuery: PageQuery(sort: 'mobile', filters: {'pool': pool.id, if (_department != 'all') 'department': _department}),
        id: (m) => m.id,
        filters: SizedBox(width: 220, child: DropdownButtonFormField<String>(
          key: ValueKey('dept-${pool.id}-$_department'), initialValue: _department, isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('Department', 'แผนก')),
          items: [
            DropdownMenuItem(value: 'all', child: Text(context.tr('All departments', 'ทุกแผนก'))),
            for (final d in departments) DropdownMenuItem(value: d, child: Text(departmentText(context, d), overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: _noDepartment, child: Text(context.tr('Not assigned', 'ยังไม่กำหนด'))),
          ],
          onChanged: (v) => setState(() => _department = v!),
        )),
        columns: [
          RemoteColumn(context.tr('Mobile number', 'หมายเลขโทรศัพท์'), (m) => Text(m.mobile), sortKey: 'mobile'),
          RemoteColumn(context.tr('Assigned to', 'ผู้ใช้งาน'), (m) => Text(m.assignedTo ?? '—'), sortKey: 'assignedTo'),
          RemoteColumn(context.tr('Department', 'แผนก'), (m) => Text(departmentText(context, m.department)), sortKey: 'department'),
          RemoteColumn(context.tr('Data used', 'ข้อมูลที่ใช้'), (m) => Text(poolData(m.usedMb, terabytes: false)), sortKey: 'usedMb'),
          RemoteColumn(context.tr('Status', 'สถานะ'), (m) => BusinessStatus(m.status), sortKey: 'status'),
        ],
        actions: (m) => IconButton(tooltip: context.tr('Details', 'รายละเอียด'), icon: const Icon(Icons.visibility_outlined), onPressed: () => showDetails(context, m.mobile, [
          (context.tr('Mobile number', 'หมายเลขโทรศัพท์'), m.mobile), (context.tr('Assigned to', 'ผู้ใช้งาน'), m.assignedTo ?? '—'),
          (context.tr('Department', 'แผนก'), departmentText(context, m.department)), (context.tr('Data used', 'ข้อมูลที่ใช้'), poolData(m.usedMb, terabytes: false)),
          (context.tr('Status', 'สถานะ'), statusText(context, m.status)),
        ])),
      )),
      const SizedBox(height: 16),
      BusinessCard(title: context.tr('Quota transactions', 'ประวัติการปรับโควตา'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('The date range filters transactions only. Usage figures above are the current snapshot.', 'ช่วงวันที่ใช้กรองเฉพาะประวัติรายการ ตัวเลขการใช้งานด้านบนเป็นข้อมูลปัจจุบัน'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DateRangeFilters(from: _from, to: _to, onChanged: (from, to) => setState(() { _from = from; _to = to; })),
          SizedBox(width: 200, child: DropdownButtonFormField<String>(
            key: ValueKey('type-$_type'), initialValue: _type, isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('Type', 'ประเภทรายการ')),
            items: [
              DropdownMenuItem(value: 'all', child: Text(context.tr('All types', 'ทุกประเภท'))),
              for (final t in ['increase', 'decrease']) DropdownMenuItem(value: t, child: Text(transactionType(context, t))),
            ],
            onChanged: (v) => setState(() => _type = v!),
          )),
          TextButton(onPressed: () => setState(() { _from = null; _to = null; _type = 'all'; }), child: Text(context.tr('Clear filters', 'ล้างตัวกรอง'))),
          OutlinedButton.icon(onPressed: invalidDates || _transactionTotal == 0 ? null : () => _export(pool), icon: const Icon(Icons.download_outlined), label: Text(context.tr('Export CSV', 'ส่งออก CSV'))),
        ]),
        if (invalidDates) ...[const SizedBox(height: 12), Notice(context.tr('From date must not be after the to date.', 'วันที่เริ่มต้นต้องไม่อยู่หลังวันที่สิ้นสุด'), kind: NoticeKind.error)],
        const SizedBox(height: 16),
        if (!invalidDates) RemoteTable<PoolTransaction>(
          key: ObjectKey(data),
          load: (q) => context.read<PoolingCubit>().repository.transactions(context.read<PoolingCubit>().corporateId, q),
          initialQuery: PageQuery(sort: 'occurredAt', direction: 'desc', filters: transactionFilters),
          onLoaded: (page) {
            final afterQuantity = page.items.any((t) => t.afterQuantityMb != null);
            if (page.total != _transactionTotal || afterQuantity != _showAfterQuantity) {
              setState(() { _transactionTotal = page.total; _showAfterQuantity = afterQuantity; });
            }
          },
          id: (t) => t.id,
          columns: [
            RemoteColumn(context.tr('Date / time (ICT)', 'วันที่ / เวลา (ไทย)'), (t) => Text(dateText(t.occurredAt)), sortKey: 'occurredAt'),
            RemoteColumn(context.tr('Type', 'ประเภทรายการ'), (t) => Text(transactionType(context, t.type)), sortKey: 'type'),
            RemoteColumn(context.tr('Change', 'จำนวนที่ปรับ'), (t) => Text(poolData(t.amountMb, terabytes: false)), sortKey: 'amountMb'),
            RemoteColumn(context.tr('Total after change', 'โควตาหลังปรับ'), (t) => Text(poolData(t.totalAfterMb, terabytes: false)), sortKey: 'totalAfterMb'),
            RemoteColumn(context.tr('Remaining after change', 'คงเหลือหลังปรับ'), (t) => Text(poolData(t.remainingAfterMb, terabytes: false)), sortKey: 'remainingAfterMb'),
            if (_showAfterQuantity) RemoteColumn(context.tr('Source quantity after change', 'ปริมาณหลังเปลี่ยนแปลง (ระบบต้นทาง)'), (t) => Text(poolData(t.afterQuantityMb, terabytes: false)), sortKey: 'afterQuantityMb'),
            RemoteColumn(context.tr('Performed by', 'ผู้ทำรายการ'), (t) => Text(t.performedBy ?? '—'), sortKey: 'performedBy'),
            RemoteColumn(context.tr('Reason', 'เหตุผล'), (t) => ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Text(t.reason ?? '—'))),
          ],
        ),
      ])),
      const SizedBox(height: 16),
    ];
  }

  void _showInventory(BuildContext context, List<PoolInventoryItem> items) => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
    title: Text(context.tr('Current inventory', 'รายการ Inventory ปัจจุบัน')),
    content: SizedBox(width: 520, child: items.isEmpty
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, size: 36, color: context.palette.muted),
            const SizedBox(height: 12),
            Text(context.tr('No inventory records', 'ไม่มีรายการ Inventory'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(context.tr('No inventory is linked to this pool.', 'ยังไม่มี Inventory ที่เชื่อมกับพูลนี้'), style: TextStyle(color: context.palette.muted)),
          ])
        : SingleChildScrollView(child: BusinessTable<PoolInventoryItem>(rows: items, id: (i) => i.id, columns: [
            BusinessColumn(context.tr('Current inventory', 'รายการ Inventory ปัจจุบัน'), (i) => Text(i.name ?? '—')),
          ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.tr('Close', 'ปิด')))],
  ));
}
