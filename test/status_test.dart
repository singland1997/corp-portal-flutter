import 'package:corp_portal_ui/features/corporate/corporate_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('terminated numbers are counted on their own, not as unknown', () {
    final c = NumberCounts.fromJson({'total': 98, 'active': 73, 'inactive': 24, 'suspended': 0, 'terminated': 1});
    expect(c.terminated, 1);
    expect(c.unknown, 0);
    expect(c.statusUnknown, isFalse);
  });

  test('older responses without terminated still parse', () {
    final c = NumberCounts.fromJson({'total': 3, 'active': 1, 'inactive': 1, 'suspended': 0});
    expect(c.terminated, 0);
    expect(c.unknown, 1);
  });

  test('a terminated number is a known status', () {
    final n = MobileNumber.fromJson({'id': 'n', 'mobile': '0', 'status': 'terminated'});
    expect(n.status, 'terminated');
  });

  test('a number page carries the latest usage day', () {
    final page = NumberPage.fromJson({'items': [], 'total': 0, 'page': 1, 'pageSize': 10,
      'counts': {'total': 0, 'active': 0, 'inactive': 0, 'suspended': 0}, 'lots': [], 'updatedAt': '2026-11-17T00:00:00Z',
      'usageThrough': '2026-11-17', 'capabilities': {'suspend': false, 'resume': false}});
    expect(page.usageThrough, '2026-11-17');
  });
}
