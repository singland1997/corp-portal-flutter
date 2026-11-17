import 'package:corp_portal_ui/features/corporate/corporate_models.dart';
import 'package:corp_portal_ui/features/corporate/number_table.dart';
import 'package:corp_portal_ui/features/reports/reports_repository.dart';
import 'package:corp_portal_ui/shared/business/page_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a number page keeps the unfiltered corporate summary next to its rows', () {
    final page = NumberPage.fromJson({
      'items': [{'id': 'n1', 'mobile': '0810000001', 'status': 'active', 'lot': null, 'usageMb': 12.5}],
      'total': 31, 'page': 2, 'pageSize': 10,
      'counts': {'total': 31, 'active': 20, 'inactive': 1, 'suspended': 0},
      'lots': [{'lot': 'L1', 'counts': {'total': 30, 'active': 20, 'inactive': 1, 'suspended': 0}}, {'lot': null, 'counts': {'total': 1, 'active': 0, 'inactive': 0, 'suspended': 0}}],
      'updatedAt': '2026-11-17T04:00:00Z', 'capabilities': {'suspend': false, 'resume': false},
    });
    expect(page.result.items.single.mobile, '0810000001');
    expect((page.result.total, page.result.page, page.result.pageSize), (31, 2, 10));
    expect(page.counts.unknown, 10);
    expect(page.lots.map((l) => l.lot), ['L1', null]);
    expect(page.canSuspend, isFalse);
  });

  test('report pages reuse the row validation of full reports', () {
    final page = PageResult.fromJson({'items': [{'date': '2026-11-01', 'dataMb': 3}], 'total': 1, 'page': 1, 'pageSize': 25}, ReportRow.fromJson);
    expect(page.items.single.values['dataMb'], 3);
    expect(() => PageResult.fromJson({'items': [{'bad': [1]}], 'total': 1, 'page': 1, 'pageSize': 25}, ReportRow.fromJson), throwsFormatException);
  });

  test('each number keeps its CRM quota balances', () {
    final n = MobileNumber.fromJson({'id': 'n1', 'mobile': '0696499649', 'quotas': [
      {'totalMb': 70, 'remainingMb': 70, 'expiresAt': '2026-12-17T07:58:10Z', 'capMax': true},
      {'totalMb': 30, 'remainingMb': 12.5, 'expiresAt': null, 'capMax': false},
    ]});
    expect(n.quotas.map((q) => q.capMax), [true, false]);
    expect(quotaText(n.quotas), '70 MB / 70 MB · 12.5 MB / 30 MB');
    expect(quotaText(MobileNumber.fromJson({'id': 'n2', 'mobile': '0'}).quotas), '—');
  });

  test('filters travel with the paging parameters', () {
    const query = PageQuery(page: 3, pageSize: 25, sort: 'occurredAt', direction: 'desc', filters: {'pool': 'p1', 'from': '2026-11-01'});
    expect(query.toQuery(), {'pool': 'p1', 'from': '2026-11-01', 'page': '3', 'pageSize': '25', 'search': '', 'sort': 'occurredAt', 'direction': 'desc'});
  });
}
