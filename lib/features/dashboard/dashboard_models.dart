import '../../core/api/portal_api.dart';
import '../../shared/business/json_read.dart';
import '../corporate/corporate_models.dart';
import '../pooling/corporate_quota.dart';

class SimActivity {
  const SimActivity({required this.operation, required this.time, this.mobile, this.status});
  factory SimActivity.fromJson(Map<String, dynamic> j) {
    final time = j.string('time');
    if (DateTime.tryParse(time) == null) throw const FormatException('Invalid activity time');
    return SimActivity(mobile: j.optionalString('mobile'), operation: j.string('operation'), status: j.optionalStatus('status'), time: time);
  }
  /// `null` when the source cannot attribute the activity to one subscriber.
  final String? mobile;
  /// Known operation key (`simReplace`, `simActivate`, `simBar`) or raw source action.
  final String operation;
  final String? status;
  final String time;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.updatedAt, required this.periodStart, required this.dailyUsageFrom, required this.numbers,
    required this.totalUsageTb, required this.poolUsedTb, required this.poolQuotaTb, required this.unknownPools,
    required this.dailyUsageGb, required this.activity, required this.activityComplete, this.corporateQuota, this.usageThrough,
  });
  factory DashboardSnapshot.fromJson(Map<String, dynamic> j) {
    final pool = jsonObject(j['pool']);
    final daily = j['dailyUsageGb'];
    if (daily is! List) throw const FormatException('Expected list: dailyUsageGb');
    final dailyFrom = j.string('dailyUsageFrom');
    if (DateTime.tryParse(dailyFrom) == null) throw const FormatException('Invalid date: dailyUsageFrom');
    return DashboardSnapshot(
      updatedAt: j.string('updatedAt'), periodStart: j.string('periodStart'), dailyUsageFrom: dailyFrom,
      numbers: NumberCounts.fromJson(jsonObject(j['numbers'])),
      totalUsageTb: j.optionalNumber('totalUsageTb'),
      poolUsedTb: pool.optionalNumber('usedTb'), poolQuotaTb: pool.optionalNumber('quotaTb'), unknownPools: pool.number('unknownPools').toInt(),
      dailyUsageGb: List.unmodifiable(daily.map((v) {
        if (v == null) return null;
        if (v is! num || !v.isFinite) throw const FormatException('Invalid daily usage');
        return v.toDouble();
      })),
      activity: jsonList(j['activity'], SimActivity.fromJson),
      activityComplete: j.boolean('activityComplete'),
      usageThrough: j.optionalString('usageThrough'),
    );
  }
  final String updatedAt, periodStart, dailyUsageFrom;
  final NumberCounts numbers;
  /// `null` = unknown; never shown as 0.
  final double? totalUsageTb, poolUsedTb, poolQuotaTb;
  final int unknownPools;
  /// `null` entries are days without source data (chart gaps).
  final List<double?> dailyUsageGb;
  final List<SimActivity> activity;
  /// `false` when part of the source activity could not be ordered and is not listed.
  final bool activityComplete;
  /// The corporate's current CRM data quota; `null` when it has none or could not be read.
  final CorporateQuota? corporateQuota;
  /// Latest day with data usage; null when the corporate has none.
  final String? usageThrough;
  DashboardSnapshot withQuota(CorporateQuota? quota) => DashboardSnapshot(
    updatedAt: updatedAt, periodStart: periodStart, dailyUsageFrom: dailyUsageFrom, numbers: numbers,
    totalUsageTb: totalUsageTb, poolUsedTb: poolUsedTb, poolQuotaTb: poolQuotaTb, unknownPools: unknownPools,
    dailyUsageGb: dailyUsageGb, activity: activity, activityComplete: activityComplete, corporateQuota: quota, usageThrough: usageThrough,
  );

  bool get poolKnown => poolUsedTb != null && poolQuotaTb != null;
  double? get poolRemainingTb => poolKnown ? poolQuotaTb! - poolUsedTb! : null;
  int? get poolPercent => poolKnown && poolQuotaTb! > 0 ? (poolUsedTb! / poolQuotaTb! * 100).round() : null;
  List<double> get knownDays => dailyUsageGb.whereType<double>().toList();
}

abstract interface class DashboardRepository {
  Future<DashboardSnapshot> load(String corporateId);
}

class ApiDashboardRepository implements DashboardRepository {
  ApiDashboardRepository(this.api);
  final PortalApi api;
  @override
  Future<DashboardSnapshot> load(String corporateId) async {
    // The quota card is optional: a failed quota read never hides the rest of the dashboard.
    final quota = CorporateQuotaRepository(api).load(corporateId).then(currentDataQuota, onError: (_) => null);
    final snapshot = DashboardSnapshot.fromJson(jsonObject(await api.request('GET', '/dashboard', corporateId: corporateId)));
    return snapshot.withQuota(await quota);
  }
}
