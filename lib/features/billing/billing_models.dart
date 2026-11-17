import 'package:intl/intl.dart';
import '../../core/api/portal_api.dart';
import '../../shared/business/json_read.dart';
import '../../shared/business/page_query.dart';

/// An invoice issued to the corporate (drafts and cancelled invoices are never sent). Amounts in THB.
class Invoice {
  const Invoice({required this.id, required this.invoiceNo, this.billingCycle, this.lot, this.invoiceType,
    this.paymentTerm, this.installments, this.grossAmount, this.discountAmount, this.vatAmount, this.netAmount,
    this.paymentStatus, this.issuedAt, this.outstanding, this.nextDueDate, this.overdue = false,
    this.lines = const [], this.schedule = const []});
  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    id: j.string('id'), invoiceNo: j.string('invoiceNo'), billingCycle: j.optionalString('billingCycle'),
    lot: j.optionalString('lot'), invoiceType: j.optionalString('invoiceType'), paymentTerm: j.optionalString('paymentTerm'),
    installments: (j['installments'] as num?)?.toInt(),
    grossAmount: j.optionalNumber('grossAmount'), discountAmount: j.optionalNumber('discountAmount'),
    vatAmount: j.optionalNumber('vatAmount'), netAmount: j.optionalNumber('netAmount'),
    paymentStatus: j.optionalString('paymentStatus'), issuedAt: j.optionalString('issuedAt'),
    outstanding: j.optionalNumber('outstanding'), nextDueDate: j.optionalString('nextDueDate'),
    overdue: j['overdue'] == true,
    lines: j['lines'] == null ? const [] : jsonList(j['lines'], InvoiceLine.fromJson),
    schedule: j['schedule'] == null ? const [] : jsonList(j['schedule'], InvoiceInstallment.fromJson),
  );
  final String id, invoiceNo;
  final String? billingCycle, lot, invoiceType, paymentTerm, paymentStatus, issuedAt, nextDueDate;
  final int? installments;
  final double? grossAmount, discountAmount, vatAmount, netAmount, outstanding;
  final bool overdue;
  final List<InvoiceLine> lines;
  final List<InvoiceInstallment> schedule;
  /// Payment state shown to the customer: overdue wins, then owed, then paid.
  String get state => overdue ? 'overdue' : (outstanding ?? 0) > 0 ? 'unpaid' : 'paid';
}

class InvoiceLine {
  const InvoiceLine({this.chargeType, this.description, this.quantity, this.unitPrice, this.amount});
  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(chargeType: j.optionalString('chargeType'),
    description: j.optionalString('description'), quantity: (j['quantity'] as num?)?.toInt(),
    unitPrice: j.optionalNumber('unitPrice'), amount: j.optionalNumber('amount'));
  final String? chargeType, description;
  final int? quantity;
  final double? unitPrice, amount;
}

class InvoiceInstallment {
  const InvoiceInstallment({this.sequenceNo, this.sequenceTotal, this.dueDate, this.amountDue, this.amountPaid, this.status});
  factory InvoiceInstallment.fromJson(Map<String, dynamic> j) => InvoiceInstallment(
    sequenceNo: (j['sequenceNo'] as num?)?.toInt(), sequenceTotal: (j['sequenceTotal'] as num?)?.toInt(),
    dueDate: j.optionalString('dueDate'), amountDue: j.optionalNumber('amountDue'),
    amountPaid: j.optionalNumber('amountPaid'), status: j.optionalString('status'));
  final int? sequenceNo, sequenceTotal;
  final String? dueDate, status;
  final double? amountDue, amountPaid;
  double? get remaining => amountDue == null ? null : (amountDue! - (amountPaid ?? 0)).clamp(0, double.infinity).toDouble();
}

/// Baht with two decimals; `null` stays "—" (never shown as 0).
String baht(double? value) => value == null ? '—' : '฿${NumberFormat('#,##0.00').format(value)}';

/// "2026-08" → "Aug 2026" / "ส.ค. 2026".
String cycleText(String? cycle, String language) {
  final parsed = cycle == null ? null : DateTime.tryParse('$cycle-01');
  return parsed == null ? (cycle ?? '—') : DateFormat('MMM yyyy', language).format(parsed);
}

class BillingRepository {
  BillingRepository(this.api);
  final PortalApi api;
  Future<PageResult<Invoice>> page(String corporateId, PageQuery query) async => PageResult.fromJson(
      jsonObject(await api.request('GET', '/invoices/page', query: query.toQuery(), corporateId: corporateId)), Invoice.fromJson);
  Future<Invoice> detail(String corporateId, String id) async =>
      Invoice.fromJson(jsonObject(await api.request('GET', '/invoices/${Uri.encodeComponent(id)}', corporateId: corporateId)));
}
