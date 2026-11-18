import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/portal_api.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/widgets/corporate_scope.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/business/formatters.dart';
import 'corporate_bloc.dart';
import 'corporate_models.dart';
import 'corporate_repository.dart';
import 'number_table.dart';

class CorporatePage extends StatelessWidget {
  const CorporatePage({super.key});
  @override
  Widget build(BuildContext context) => CorporateScope(builder: (context, id) => BlocProvider(
    create: (_) => CorporateBloc(ApiCorporateRepository(context.read<PortalApi>()), id),
    child: _CorporateView(corporateId: id),
  ));
}

class _CorporateView extends StatefulWidget {
  const _CorporateView({required this.corporateId});
  final String corporateId;
  @override
  State<_CorporateView> createState() => _CorporateViewState();
}

class _CorporateViewState extends State<_CorporateView> {
  Set<String> _selected = {};
  int _revision = 0;
  Future<void> _confirm(String action) async {
    final bloc = context.read<CorporateBloc>();
    final ids = _selected.toList();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(action == 'suspend' ? context.tr('Suspend numbers', 'ระงับเลขหมาย') : context.tr('Resume numbers', 'เปิดใช้งานเลขหมาย')),
      content: Text('${context.tr('Confirm this operation for', 'ยืนยันการดำเนินการสำหรับ')} ${ids.length} ${context.tr('numbers?', 'เลขหมาย?')}'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel', 'ยกเลิก'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Confirm', 'ยืนยัน')))],
    ));
    if (confirmed == true && mounted && !bloc.isClosed) bloc.add(NumberCommandRequested(action, ids));
  }
  @override
  Widget build(BuildContext context) => BlocConsumer<CorporateBloc, CorporateState>(
    listenWhen: (before, after) => after.results.isNotEmpty && !identical(before.results, after.results),
    listener: (context, state) => setState(() => _selected = state.results.where((r) => r.outcome != 'accepted').map((r) => r.id).toSet()),
    builder: (context, state) {
      final bloc = context.read<CorporateBloc>();
      final summary = state.summary;
      final c = summary?.counts;
      String count(int? n) => c == null || c.statusUnknown ? '—' : '$n';
      return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, children: [Text(context.tr('Corporate management', 'จัดการองค์กร'), style: Theme.of(context).textTheme.headlineMedium), IconButton(tooltip: context.tr('Refresh', 'โหลดใหม่'), onPressed: state.busy ? null : () => setState(() { _revision++; _selected = {}; }), icon: const Icon(Icons.refresh))]),
        const SizedBox(height: 20),
        DataMetrics(items: [
          (context.tr('Total numbers', 'เลขหมายทั้งหมด'), c == null ? '—' : '${c.total}'),
          // Unmapped CRM statuses are not counted as 0 active / inactive.
          (context.tr('Active', 'ใช้งาน'), count(c?.active)),
          (context.tr('Inactive', 'ไม่ใช้งาน'), count(c?.inactive)),
          (context.tr('Suspended', 'ระงับ'), count(c?.suspended)),
          if (c != null && c.terminated > 0) (context.tr('Terminated', 'ยกเลิกแล้ว'), '${c.terminated}'),
          if (c != null && c.unknown > 0) (context.tr('Status unknown', 'ไม่ทราบสถานะ'), '${c.unknown}'),
        ]),
        const SizedBox(height: 16),
        BusinessCard(title: context.tr('Lot overview', 'ภาพรวมล็อต'), child: Wrap(spacing: 24, runSpacing: 12, children: [for (final l in summary?.lots ?? const <LotOverview>[]) SizedBox(width: 240, child: FieldDetails(items: [(l.lot ?? context.tr('Unknown lot', 'ไม่ทราบล็อต'), '${l.counts.total} ${context.tr('numbers', 'เลขหมาย')}'), (context.tr('Product', 'ผลิตภัณฑ์'), l.productName ?? '—'), (context.tr('Quota type', 'ประเภทโควตา'), lotQuotaTypeText(context, l.quotaType)),(context.tr('Active / Inactive / Suspended', 'ใช้งาน / ไม่ใช้งาน / ระงับ'), '${l.counts.active} / ${l.counts.inactive} / ${l.counts.suspended}'), if (l.counts.terminated > 0) (context.tr('Terminated', 'ยกเลิกแล้ว'), '${l.counts.terminated}')]))])),
        const SizedBox(height: 16),
        if (state.commandError != null) Padding(padding: const EdgeInsets.all(12), child: Text(businessError(context, state.commandError), style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (state.results.isNotEmpty) BusinessCard(title: context.tr('Operation results', 'ผลการดำเนินการ'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Accepted requests are not completed operations. Status updates after synchronization.', 'การรับคำขอไม่ได้แปลว่าดำเนินการเสร็จ สถานะจะอัปเดตหลังซิงก์ข้อมูล')),
          const SizedBox(height: 12),
          ...state.results.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(r.mobile), BusinessStatus(r.outcome), if (r.errorCode != null) Text(r.errorCode!)]))),
        ])),
        BusinessCard(title: context.tr('Mobile numbers', 'รายการเลขหมาย'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${_selected.length} ${context.tr('selected', 'รายการที่เลือก')}'),
            OutlinedButton.icon(onPressed: state.busy || _selected.isEmpty || !(summary?.canSuspend ?? false) ? null : () => _confirm('suspend'), icon: const Icon(Icons.pause), label: Text(context.tr('Suspend', 'ระงับ'))),
            OutlinedButton.icon(onPressed: state.busy || _selected.isEmpty || !(summary?.canResume ?? false) ? null : () => _confirm('resume'), icon: const Icon(Icons.play_arrow), label: Text(context.tr('Resume', 'เปิดใช้งาน'))),
            if (state.busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          if (summary != null && (!summary.canSuspend || !summary.canResume)) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(context.tr('Number operations require the provisioning service connection.', 'การดำเนินการกับเลขหมายต้องเชื่อมต่อบริการ Provisioning'))),
          const SizedBox(height: 16),
          IgnorePointer(ignoring: state.busy, child: NumberTable(key: ValueKey(_revision), load: (q) => bloc.repository.numbers(widget.corporateId, q), onLoaded: (page) { if (!bloc.isClosed) bloc.add(CorporateSummaryLoaded(page)); }, selected: _selected, onSelectionChanged: (ids) => setState(() => _selected = ids))),
          const SizedBox(height: 12),
          Text('${context.tr('Data as of', 'ข้อมูล ณ')} ${summary == null ? '—' : dateText(summary.updatedAt)}', style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]));
    },
  );
}

/// Lot quota type label; anything but the three CRM types reads as unknown, null as "—".
String lotQuotaTypeText(BuildContext context, String? type) => switch (type) {
  null => '—',
  'product-quota' => context.tr('Product quota', 'โควตาตามผลิตภัณฑ์'),
  'share-in-group' => context.tr('Share in group', 'แชร์ในกลุ่ม'),
  'corporate-quota' => context.tr('Corporate quota', 'โควตาองค์กร'),
  _ => context.tr('Unknown', 'ไม่ทราบ'),
};
