import 'package:corp_portal_ui/features/pooling/corporate_quota.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CorporateQuota quota(Map<String, dynamic> j) => CorporateQuota.fromJson({'id': 'q', ...j});

  test('use beyond the quota is shown as over 100 percent, not clamped', () {
    final q = quota({'service': 'DATA', 'unit': 'MB', 'total': 51200, 'remaining': -144324, 'used': 195524, 'activeMembers': 51});
    expect(q.overQuota, isTrue);
    expect(q.usedPercent, 382);
    expect(q.amount(q.total), '50 GB');
    expect(q.amount(q.remaining), '-140.94 GB');
  });

  test('non-data services keep the CRM unit and an unknown share stays unknown', () {
    final voice = quota({'service': 'VOICE', 'unit': 'SEC', 'total': 0, 'remaining': 0, 'used': 0});
    expect(voice.amount(voice.total), '0 SEC');
    expect(voice.usedPercent, isNull);
  });

  test('the dashboard uses the current data quota only', () {
    final quotas = [
      quota({'service': 'DATA', 'unit': 'MB', 'expired': true}),
      quota({'service': 'VOICE', 'unit': 'SEC'}),
      CorporateQuota.fromJson({'id': 'now', 'service': 'DATA', 'unit': 'MB', 'expired': false}),
    ];
    expect(currentDataQuota(quotas)?.id, 'now');
    expect(currentDataQuota(const []), isNull);
  });
}
