import 'package:material_ui/material_ui.dart';
import '../../core/api/portal_api.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/business/formatters.dart';
import '../../shared/business/json_read.dart';
import '../../shared/business/paged_table.dart';

/// The corporate's own quota for one service (CRM CORPORATE_QUOTA bucket).
/// DATA is in MB; other services keep the CRM unit (`SEC`, `MSG`).
class CorporateQuota {
  const CorporateQuota({required this.id, this.service, this.unit, this.total, this.remaining, this.used,
    this.activeMembers = 0, this.startsAt, this.expiresAt, this.status, this.expired = false});
  factory CorporateQuota.fromJson(Map<String, dynamic> j) => CorporateQuota(
    id: j.string('id'), service: j.optionalString('service'), unit: j.optionalString('unit'),
    total: j.optionalNumber('total'), remaining: j.optionalNumber('remaining'), used: j.optionalNumber('used'),
    activeMembers: (j['activeMembers'] as num?)?.toInt() ?? 0,
    startsAt: j.optionalString('startsAt'), expiresAt: j.optionalString('expiresAt'),
    status: j.optionalString('status'), expired: j['expired'] == true,
  );
  final String id;
  final String? service, unit, startsAt, expiresAt, status;
  final double? total, remaining, used;
  final int activeMembers;
  final bool expired;

  bool get isData => unit == 'MB';
  /// Used more than the quota (the CRM keeps deducting, remaining goes below zero).
  bool get overQuota => (remaining ?? 0) < 0;
  /// Can exceed 100 when over quota; `null` when unknown or the quota is 0.
  int? get usedPercent => used != null && total != null && total! > 0 ? (used! / total! * 100).round() : null;
  String amount(double? value) => isData ? dataSize(value) : value == null ? '—' : '${numberText(value)} ${unit ?? ''}'.trim();
}

class QuotaHistoryEntry {
  const QuotaHistoryEntry({required this.id, this.occurredAt, this.action, this.service, this.changeMb, this.afterMb, this.description});
  factory QuotaHistoryEntry.fromJson(Map<String, dynamic> j) => QuotaHistoryEntry(
    id: j.string('id'), occurredAt: j.optionalString('occurredAt'), action: j.optionalString('action'),
    service: j.optionalString('service'), changeMb: j.optionalNumber('changeMb'), afterMb: j.optionalNumber('afterMb'),
    description: j.optionalString('description'),
  );
  final String id;
  final String? occurredAt, action, service, description;
  final double? changeMb, afterMb;
}

class CorporateQuotaRepository {
  CorporateQuotaRepository(this.api);
  final PortalApi api;
  Future<List<CorporateQuota>> load(String corporateId) async =>
      jsonList(jsonObject(await api.request('GET', '/pools/corporate-quota', corporateId: corporateId))['items'], CorporateQuota.fromJson);
  Future<PageResult<QuotaHistoryEntry>> history(String corporateId, PageQuery query) async => PageResult.fromJson(
      jsonObject(await api.request('GET', '/pools/corporate-quota/history/page', query: query.toQuery(), corporateId: corporateId)),
      QuotaHistoryEntry.fromJson);
}

/// Current data quota of the corporate, or `null` when it has none.
CorporateQuota? currentDataQuota(List<CorporateQuota> quotas) =>
    quotas.where((q) => q.isData && !q.expired).firstOrNull;

String quotaAction(BuildContext context, String? action) => switch (action) {
  'DEDUCT' => context.tr('Usage deducted', 'ตัดการใช้งาน'),
  'REFILL' => context.tr('Refill', 'เติมโควตา'),
  'TOPUP' => context.tr('Top-up', 'เติมเพิ่ม'),
  'INITIAL' => context.tr('Initial quota', 'ตั้งโควตาเริ่มต้น'),
  'DEACTIVATE_MEMBER' => context.tr('Member removed', 'นำเบอร์ออก'),
  null => '—',
  _ => action,
};

/// Corporate quota balances and their history (Pooling page).
class CorporateQuotaSection extends StatefulWidget {
  const CorporateQuotaSection({super.key, required this.repository, required this.corporateId});
  final CorporateQuotaRepository repository;
  final String corporateId;
  @override
  State<CorporateQuotaSection> createState() => _CorporateQuotaSectionState();
}

class _CorporateQuotaSectionState extends State<CorporateQuotaSection> {
  late Future<List<CorporateQuota>> _quotas = widget.repository.load(widget.corporateId);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CorporateQuota>>(future: _quotas, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const BusinessCard(child: LinearProgressIndicator());
    if (snapshot.hasError) {
      return BusinessCard(title: context.tr('Corporate quota', 'โควตาองค์กร'),
        child: BusinessFeedback(error: snapshot.error, retry: () => setState(() => _quotas = widget.repository.load(widget.corporateId))));
    }
    final quotas = snapshot.data!;
    final current = quotas.where((q) => !q.expired).toList();
    final expired = quotas.length - current.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BusinessCard(title: context.tr('Corporate quota', 'โควตาองค์กร'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('The quota the corporate buys from the CRM. Every active member number uses it.', 'โควตาที่องค์กรซื้อไว้ในระบบ CRM ใช้ร่วมกันทุกเบอร์ที่เป็นสมาชิก'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        if (current.isEmpty) Text(context.tr('This corporate has no active quota.', 'องค์กรนี้ยังไม่มีโควตาที่ใช้งานอยู่'))
        else Wrap(spacing: 16, runSpacing: 16, children: [for (final q in current) _QuotaTile(quota: q)]),
        if (expired > 0) Padding(padding: const EdgeInsets.only(top: 12), child: Text(
          '$expired ${context.tr('expired quota not shown', 'โควตาที่หมดอายุแล้ว ไม่แสดง')}', style: Theme.of(context).textTheme.bodySmall)),
      ])),
      if (quotas.isNotEmpty) ...[
        const SizedBox(height: 16),
        BusinessCard(title: context.tr('Corporate quota history', 'ประวัติโควตาองค์กร'), child: RemoteTable<QuotaHistoryEntry>(
          load: (q) => widget.repository.history(widget.corporateId, q),
          initialQuery: const PageQuery(sort: 'occurredAt', direction: 'desc'),
          id: (h) => h.id,
          columns: [
            RemoteColumn(context.tr('Date / time (ICT)', 'วันที่ / เวลา (ไทย)'), (h) => Text(dateText(h.occurredAt)), sortKey: 'occurredAt'),
            RemoteColumn(context.tr('Type', 'ประเภท'), (h) => Text(quotaAction(context, h.action)), sortKey: 'action'),
            RemoteColumn(context.tr('Service', 'บริการ'), (h) => Text(h.service ?? '—'), sortKey: 'service'),
            RemoteColumn(context.tr('Change', 'จำนวนที่เปลี่ยน'), (h) => Text(dataSize(h.changeMb)), sortKey: 'changeMb'),
            RemoteColumn(context.tr('After change (source)', 'หลังเปลี่ยน (ต้นทาง)'), (h) => Text(dataSize(h.afterMb)), sortKey: 'afterMb'),
            RemoteColumn(context.tr('Note', 'หมายเหตุ'), (h) => ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: Text(h.description ?? '—'))),
          ],
        )),
      ],
    ]);
  });
}

class _QuotaTile extends StatelessWidget {
  const _QuotaTile({required this.quota});
  final CorporateQuota quota;
  @override
  Widget build(BuildContext context) {
    final q = quota;
    final percent = q.usedPercent;
    final danger = Theme.of(context).colorScheme.error;
    return SizedBox(width: 320, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(q.service ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        if (q.overQuota) Text(context.tr('Over quota', 'ใช้เกินโควตา'), style: TextStyle(color: danger, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
        minHeight: 8, value: percent == null ? 0 : (percent / 100).clamp(0, 1).toDouble(),
        color: q.overQuota ? danger : null)),
      const SizedBox(height: 8),
      FieldDetails(items: [
        (context.tr('Used / quota', 'ใช้ไป / โควตา'), '${q.amount(q.used)} / ${q.amount(q.total)}${percent == null ? '' : ' ($percent%)'}'),
        (context.tr('Remaining', 'คงเหลือ'), q.amount(q.remaining)),
        (context.tr('Member numbers', 'เบอร์ที่ใช้ร่วม'), numberText(q.activeMembers)),
        (context.tr('Valid until', 'ใช้ได้ถึง'), dateText(q.expiresAt, time: false)),
      ]),
    ]));
  }
}
