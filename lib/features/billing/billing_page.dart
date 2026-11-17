import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/portal_api.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/business/formatters.dart';
import '../../shared/business/paged_table.dart';
import '../../shared/widgets/corporate_scope.dart';
import 'billing_models.dart';

/// Invoices issued to the selected corporate, one API page at a time.
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});
  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  late final _repository = BillingRepository(context.read<PortalApi>());
  String _state = 'all';

  String _stateText(BuildContext context, String state) => switch (state) {
    'overdue' => context.tr('Overdue', 'เกินกำหนด'),
    'unpaid' => context.tr('Awaiting payment', 'รอชำระ'),
    'paid' => context.tr('Paid', 'ชำระแล้ว'),
    _ => context.tr('All', 'ทั้งหมด'),
  };

  Widget _stateBadge(BuildContext context, Invoice i) {
    final color = switch (i.state) { 'overdue' => Colors.red, 'unpaid' => Colors.orange, _ => Colors.green };
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(_stateText(context, i.state), style: TextStyle(color: color.shade800, fontSize: 12))),
    );
  }

  Future<void> _open(String corporateId, Invoice row) => showDialog<void>(context: context, builder: (_) =>
      _InvoiceDialog(future: _repository.detail(corporateId, row.id), badge: (i) => _stateBadge(context, i)));

  @override
  Widget build(BuildContext context) => CorporateScope(builder: (context, id) {
    final language = Localizations.localeOf(context).languageCode;
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title: context.tr('Billing', 'ใบแจ้งหนี้')),
      const SizedBox(height: 8),
      Text(context.tr('Invoices issued to this corporate. Amounts in Thai baht including VAT.', 'ใบแจ้งหนี้ที่ออกให้องค์กรนี้ จำนวนเงินเป็นบาท รวม VAT'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 20),
      BusinessCard(child: RemoteTable<Invoice>(
        load: (q) => _repository.page(id, q),
        initialQuery: PageQuery(sort: 'billingCycle', direction: 'desc', filters: {if (_state != 'all') 'state': _state}),
        id: (i) => i.id,
        filters: SizedBox(width: 200, child: DropdownButtonFormField<String>(
          initialValue: _state, isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('Payment', 'การชำระ')),
          items: [for (final s in ['all', 'unpaid', 'overdue', 'paid']) DropdownMenuItem(value: s, child: Text(_stateText(context, s)))],
          onChanged: (v) => setState(() => _state = v!),
        )),
        columns: [
          RemoteColumn(context.tr('Invoice no.', 'เลขที่ใบแจ้งหนี้'), (i) => Text(i.invoiceNo), sortKey: 'invoiceNo'),
          RemoteColumn(context.tr('Billing cycle', 'รอบบิล'), (i) => Text(cycleText(i.billingCycle, language)), sortKey: 'billingCycle'),
          RemoteColumn(context.tr('Lot', 'ล็อต'), (i) => Text(i.lot ?? '—')),
          RemoteColumn(context.tr('Total', 'ยอดรวม'), (i) => Text(baht(i.netAmount)), sortKey: 'netAmount'),
          RemoteColumn(context.tr('Outstanding', 'ค้างชำระ'), (i) => Text(baht(i.outstanding)), sortKey: 'outstanding'),
          RemoteColumn(context.tr('Next due', 'ครบกำหนดถัดไป'), (i) => Text(i.nextDueDate == null ? '—' : dateText(i.nextDueDate, time: false)), sortKey: 'nextDueDate'),
          RemoteColumn(context.tr('Status', 'สถานะ'), (i) => _stateBadge(context, i)),
        ],
        actions: (i) => IconButton(tooltip: context.tr('Invoice details', 'รายละเอียดใบแจ้งหนี้'), icon: const Icon(Icons.visibility_outlined), onPressed: () => _open(id, i)),
      )),
    ]));
  });
}

class _InvoiceDialog extends StatelessWidget {
  const _InvoiceDialog({required this.future, required this.badge});
  final Future<Invoice> future;
  final Widget Function(Invoice) badge;

  String _charge(BuildContext context, String? type) => switch (type) {
    'PACKAGE' => context.tr('Package', 'แพ็กเกจ'),
    'USAGE' => context.tr('Usage', 'ค่าใช้งาน'),
    'MAINTAIN_FEE' => context.tr('Number fee', 'ค่ารักษาหมายเลข'),
    'DISCOUNT' => context.tr('Discount', 'ส่วนลด'),
    null => '—',
    _ => type,
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('Invoice details', 'รายละเอียดใบแจ้งหนี้')),
    content: SizedBox(width: 720, child: FutureBuilder<Invoice>(future: future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const LinearProgressIndicator();
      if (snapshot.hasError) return BusinessFeedback(error: snapshot.error);
      final i = snapshot.data!;
      final language = Localizations.localeOf(context).languageCode;
      final small = Theme.of(context).textTheme.bodySmall;
      return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(i.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)), badge(i)]),
        const SizedBox(height: 12),
        Wrap(spacing: 32, children: [
          SizedBox(width: 200, child: FieldDetails(items: [
            (context.tr('Billing cycle', 'รอบบิล'), cycleText(i.billingCycle, language)),
            (context.tr('Issued', 'วันที่ออก'), dateText(i.issuedAt, time: false)),
          ])),
          SizedBox(width: 200, child: FieldDetails(items: [
            (context.tr('Lot', 'ล็อต'), i.lot ?? '—'),
            (context.tr('Payment', 'การชำระ'), i.paymentTerm == 'INSTALLMENT'
                ? '${context.tr('Installments', 'ผ่อนชำระ')} ${i.installments ?? '—'} ${context.tr('payments', 'งวด')}'
                : context.tr('Single payment', 'ชำระครั้งเดียว')),
          ])),
          SizedBox(width: 200, child: FieldDetails(items: [
            (context.tr('Outstanding', 'ค้างชำระ'), baht(i.outstanding)),
            (context.tr('Next due', 'ครบกำหนดถัดไป'), i.nextDueDate == null ? '—' : dateText(i.nextDueDate, time: false)),
          ])),
        ]),
        Text(context.tr('Charges', 'รายการค่าใช้จ่าย'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: [
          DataColumn(label: Text(context.tr('Type', 'ประเภท'))),
          DataColumn(label: Text(context.tr('Description', 'รายละเอียด'))),
          DataColumn(label: Text(context.tr('Qty', 'จำนวน')), numeric: true),
          DataColumn(label: Text(context.tr('Unit price', 'ราคาต่อหน่วย')), numeric: true),
          DataColumn(label: Text(context.tr('Amount', 'จำนวนเงิน')), numeric: true),
        ], rows: [
          for (final l in i.lines) DataRow(cells: [
            DataCell(Text(_charge(context, l.chargeType))),
            DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Text(l.description ?? '—'))),
            DataCell(Text(numberText(l.quantity))),
            DataCell(Text(baht(l.unitPrice))),
            DataCell(Text(baht(l.amount))),
          ]),
        ])),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: SizedBox(width: 280, child: Column(children: [
          for (final (label, value) in [
            (context.tr('Subtotal', 'รวมก่อนภาษี'), i.grossAmount),
            if ((i.discountAmount ?? 0) != 0) (context.tr('Discount', 'ส่วนลด'), -(i.discountAmount!)),
            (context.tr('VAT 7%', 'ภาษีมูลค่าเพิ่ม 7%'), i.vatAmount),
            (context.tr('Total', 'ยอดรวมทั้งสิ้น'), i.netAmount),
          ]) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
            Expanded(child: Text(label, style: small)), Text(baht(value), style: const TextStyle(fontWeight: FontWeight.w500)),
          ])),
        ]))),
        if (i.schedule.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.tr('Payment schedule', 'งวดการชำระ'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: [
            DataColumn(label: Text(context.tr('Payment', 'งวด'))),
            DataColumn(label: Text(context.tr('Due date', 'ครบกำหนด'))),
            DataColumn(label: Text(context.tr('Amount due', 'ยอดที่ต้องชำระ')), numeric: true),
            DataColumn(label: Text(context.tr('Paid', 'ชำระแล้ว')), numeric: true),
            DataColumn(label: Text(context.tr('Remaining', 'คงเหลือ')), numeric: true),
          ], rows: [
            for (final s in i.schedule) DataRow(cells: [
              DataCell(Text('${s.sequenceNo ?? '—'}/${s.sequenceTotal ?? '—'}')),
              DataCell(Text(s.dueDate == null ? '—' : dateText(s.dueDate, time: false))),
              DataCell(Text(baht(s.amountDue))),
              DataCell(Text(baht(s.amountPaid))),
              DataCell(Text(baht(s.remaining))),
            ]),
          ])),
        ],
      ]));
    })),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Close', 'ปิด')))],
  );
}
