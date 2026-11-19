import 'package:material_ui/material_ui.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/business/formatters.dart';
import '../../shared/business/paged_table.dart';
import 'corporate_models.dart';

const unknownLot = '__unknown__';

/// Corporate numbers, one API page at a time. Status/lot filters, search and sort run in SQL.
class NumberTable extends StatefulWidget {
  const NumberTable({super.key, required this.load, this.selected, this.onSelectionChanged, this.onLoaded});
  final Future<NumberPage> Function(PageQuery) load;
  final Set<String>? selected;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final ValueChanged<NumberPage>? onLoaded;
  @override
  State<NumberTable> createState() => _NumberTableState();
}

class _NumberTableState extends State<NumberTable> {
  String _status = 'all', _lot = 'all';
  // Lot options come from the server's unfiltered lot summary, not the visible rows.
  List<String?> _lots = const [];
  // Latest day with usage data; the "Data used" column counts from the month start to it.
  String? _usageThrough;
  bool _loaded = false;

  Future<PageResult<MobileNumber>> _load(PageQuery query) async {
    final page = await widget.load(query);
    if (mounted) {
      final lots = page.lots.map((l) => l.lot).toList();
      if (lots.length != _lots.length || !lots.every(_lots.contains)) setState(() => _lots = lots);
      if (!_loaded || page.usageThrough != _usageThrough) setState(() { _loaded = true; _usageThrough = page.usageThrough; });
      widget.onLoaded?.call(page);
    }
    return page.result;
  }

  void _set(VoidCallback change) => setState(() { change(); widget.onSelectionChanged?.call({}); });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    // Always present, so the table below keeps its place (and state) when the note appears.
    _loaded ? Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(
      _usageThrough == null
          ? context.tr('Data used: no usage data from the CRM yet.', 'ข้อมูลที่ใช้: ยังไม่มีข้อมูลการใช้งานจาก CRM')
          : '${context.tr('Data used counts from the start of the month to', 'ข้อมูลที่ใช้ นับตั้งแต่ต้นเดือนถึง')} ${dateText(_usageThrough, time: false)}',
      style: Theme.of(context).textTheme.bodySmall)) : const SizedBox.shrink(),
    _table(context),
  ]);

  Widget _table(BuildContext context) => RemoteTable<MobileNumber>(
    load: _load, id: (n) => n.id,
    initialQuery: PageQuery(sort: 'mobile', filters: {if (_status != 'all') 'status': _status, if (_lot != 'all') 'lot': _lot}),
    selected: widget.selected, onSelectionChanged: widget.onSelectionChanged,
    filters: Wrap(spacing: 12, runSpacing: 12, children: [
      SizedBox(width: 180, child: DropdownButtonFormField<String>(initialValue: _status, isExpanded: true, decoration: InputDecoration(labelText: context.tr('Status', 'สถานะ')),
        items: ['all', 'active', 'inactive', 'suspended', 'pending', 'failed', 'terminated', 'unknown'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'all' ? context.tr('All statuses', 'ทุกสถานะ') : statusText(context, s)))).toList(),
        onChanged: (v) => _set(() => _status = v!))),
      SizedBox(width: 200, child: DropdownButtonFormField<String>(key: ValueKey('lots-${_lots.length}'), initialValue: _lot, isExpanded: true, decoration: InputDecoration(labelText: context.tr('Lot', 'ล็อต')),
        items: [DropdownMenuItem(value: 'all', child: Text(context.tr('All lots', 'ทุกล็อต'))), ..._lots.map((l) => DropdownMenuItem(value: l ?? unknownLot, child: Text(l ?? context.tr('Unknown', 'ไม่ทราบ'), overflow: TextOverflow.ellipsis)))],
        onChanged: (v) => _set(() => _lot = v!))),
    ]),
    columns: [
      RemoteColumn(context.tr('Mobile number', 'เลขหมาย'), (n) => Text(n.mobile), sortKey: 'mobile'),
      RemoteColumn(context.tr('Lot', 'ล็อต'), (n) => Text(n.lot ?? '—'), sortKey: 'lot'),
      RemoteColumn(context.tr('Assigned to', 'ผู้ใช้งาน'), (n) => Text(n.owner ?? '—'), sortKey: 'owner'),
      RemoteColumn(context.tr('Package', 'แพ็กเกจ'), (n) => Text(n.package ?? '—'), sortKey: 'package'),
      RemoteColumn(context.tr('Quota left', 'โควตาคงเหลือ'), (n) => Text(quotaText(n.quotas))),
      RemoteColumn(context.tr('Data used', 'ข้อมูลที่ใช้'), (n) => Text(dataSize(n.usageMb)), sortKey: 'usageMb'),
      RemoteColumn(context.tr('Status', 'สถานะ'), (n) => BusinessStatus(n.status), sortKey: 'status'),
    ],
    actions: (n) => IconButton(tooltip: context.tr('Details', 'รายละเอียด'), icon: const Icon(Icons.visibility_outlined), onPressed: () => showDetails(context, n.mobile, [
      (context.tr('Mobile number', 'เลขหมาย'), n.mobile), ('ICCID', n.iccid ?? '—'),
      (context.tr('Assigned to', 'ผู้ใช้งาน'), n.owner ?? '—'), (context.tr('Lot', 'ล็อต'), n.lot ?? '—'),
      (context.tr('Product', 'ผลิตภัณฑ์'), n.productName ?? '—'),
      (context.tr('Package', 'แพ็กเกจ'), n.packageName ?? n.package ?? '—'),
      for (final (i, q) in n.quotas.indexed) (
        '${context.tr('Data quota', 'โควตาดาต้า')} ${i + 1}${q.capMax == true ? ' (Cap max)' : ''}',
        '${quotaText([q])} · ${context.tr('expires', 'หมดอายุ')} ${dateText(q.expiresAt, time: false)}',
      ),
      if (n.quotas.isEmpty) (context.tr('Data quota', 'โควตาดาต้า'), '—'),
      (context.tr('Data used', 'ข้อมูลที่ใช้'), dataSize(n.usageMb)), (context.tr('Status', 'สถานะ'), statusText(context, n.status)),
      (context.tr('Subscriber status (CRM)', 'สถานะผู้ใช้บริการ (CRM)'), n.sourceStatus ?? '—'),
    ])),
  );
}

/// "remaining / total" per balance, e.g. "70 MB / 70 MB · 30 MB / 30 MB" (same order as the API).
String quotaText(List<NumberQuota> quotas) => quotas.isEmpty
    ? '—'
    : quotas.map((q) => '${dataSize(q.remainingMb)} / ${dataSize(q.totalMb)}').join(' · ');
