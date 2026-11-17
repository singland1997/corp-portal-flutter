import 'package:corp_portal_ui/features/billing/billing_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  final detail = Invoice.fromJson({
    'id': 'i1', 'invoiceNo': 'INV-202608-1003', 'billingCycle': '2026-08', 'paymentTerm': 'INSTALLMENT', 'installments': 3,
    'grossAmount': 808.68, 'vatAmount': 56.61, 'netAmount': 865.29, 'outstanding': 365.29, 'nextDueDate': '2026-12-10', 'overdue': false,
    'lines': [{'chargeType': 'PACKAGE', 'description': 'x', 'quantity': 1, 'unitPrice': 40, 'amount': 40}],
    'schedule': [{'sequenceNo': 2, 'sequenceTotal': 3, 'dueDate': '2026-12-10', 'amountDue': 288.43, 'amountPaid': 211.57, 'status': 'PARTIAL'}],
  });

  test('an invoice with lines and installments parses', () {
    expect(detail.lines.single.amount, 40);
    expect(detail.schedule.single.remaining, closeTo(76.86, 1e-9));
    expect(detail.state, 'unpaid');
  });

  test('overdue wins over unpaid, nothing owed is paid', () {
    expect(Invoice.fromJson({'id': 'a', 'invoiceNo': 'A', 'outstanding': 10, 'overdue': true}).state, 'overdue');
    expect(Invoice.fromJson({'id': 'b', 'invoiceNo': 'B', 'outstanding': 0}).state, 'paid');
    expect(Invoice.fromJson({'id': 'c', 'invoiceNo': 'C'}).state, 'paid');
  });

  test('money and cycles are formatted for people', () {
    expect(baht(865.29), '฿865.29');
    expect(baht(194973.37), '฿194,973.37');
    expect(baht(null), '—');
    expect(cycleText('2026-08', 'en'), 'Aug 2026');
    expect(cycleText(null, 'en'), '—');
  });
}
