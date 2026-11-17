import '../../shared/business/json_read.dart';
import '../../shared/business/page_query.dart';

class MobileNumber {
  const MobileNumber({required this.id, required this.mobile, this.owner, this.package, this.status, this.usageMb, this.iccid, this.lot, this.quotas = const []});
  factory MobileNumber.fromJson(Map<String, dynamic> j) => MobileNumber(id: j.string('id'), mobile: j.string('mobile'), owner: j.optionalString('owner'), package: j.optionalString('package'), status: j.optionalStatus('status'), usageMb: j.optionalNumber('usageMb'), iccid: j.optionalString('iccid'), lot: j.optionalString('lot'), quotas: j['quotas'] == null ? const [] : jsonList(j['quotas'], NumberQuota.fromJson));
  /// Current data balances (CRM PRODUCT_QUOTA buckets).
  final List<NumberQuota> quotas;
  final String id, mobile;
  final String? owner, package, status, iccid, lot;
  final double? usageMb;
  String get searchable => [mobile, owner, package, iccid, lot].whereType<String>().join(' ');
}

class NumberCounts {
  const NumberCounts({required this.total, required this.active, required this.inactive, required this.suspended, this.terminated = 0});
  factory NumberCounts.fromJson(Map<String, dynamic> j) => NumberCounts(total: j.number('total').toInt(), active: j.number('active').toInt(), inactive: j.number('inactive').toInt(), suspended: j.number('suspended').toInt(), terminated: j.optionalNumber('terminated')?.toInt() ?? 0);
  /// [terminated]: cancelled in the CRM (absent in older responses, read as 0).
  final int total, active, inactive, suspended, terminated;
  /// Numbers whose CRM status is not mapped to a Portal status (never counted as 0 active).
  int get unknown => (total - active - inactive - suspended - terminated).clamp(0, total);
  /// Every status is unknown: per-status counts mean nothing, show "—".
  bool get statusUnknown => total > 0 && unknown == total;
}

class CommandResult {
  const CommandResult({required this.id, required this.mobile, required this.outcome, this.errorCode});
  factory CommandResult.fromJson(Map<String, dynamic> j) => CommandResult(id: j.string('id'), mobile: j.string('mobile'), outcome: j.enumString('outcome', {'accepted', 'rejected', 'failed', 'unknown'}), errorCode: j.optionalString('errorCode'));
  final String id, mobile, outcome;
  final String? errorCode;
}

/// Unfiltered per-lot counts from the server (never derived from the visible page).
class LotOverview {
  const LotOverview({required this.lot, required this.counts});
  factory LotOverview.fromJson(Map<String, dynamic> j) => LotOverview(lot: j.optionalString('lot'), counts: NumberCounts.fromJson(jsonObject(j['counts'])));
  final String? lot;
  final NumberCounts counts;
}

/// One page of `GET /corporates/{id}/numbers` plus the corporate's unfiltered summary.
class NumberPage {
  const NumberPage({required this.result, required this.counts, required this.lots, required this.updatedAt, required this.canSuspend, required this.canResume, this.usageThrough});
  factory NumberPage.fromJson(Map<String, dynamic> j) {
    final capabilities = jsonObject(j['capabilities']);
    return NumberPage(
      result: PageResult.fromJson(j, MobileNumber.fromJson),
      counts: NumberCounts.fromJson(jsonObject(j['counts'])),
      lots: jsonList(j['lots'], LotOverview.fromJson),
      updatedAt: j.string('updatedAt'),
      usageThrough: j.optionalString('usageThrough'),
      canSuspend: capabilities.boolean('suspend'), canResume: capabilities.boolean('resume'),
    );
  }
  final PageResult<MobileNumber> result;
  final NumberCounts counts;
  final List<LotOverview> lots;
  final String updatedAt;
  /// Latest day with data usage; the usage column runs from the month start to this day.
  final String? usageThrough;
  final bool canSuspend, canResume;
}

/// One data balance of a number in MB; `null` when the source unit is unknown.
class NumberQuota {
  const NumberQuota({this.totalMb, this.remainingMb, this.expiresAt, this.capMax});
  factory NumberQuota.fromJson(Map<String, dynamic> j) => NumberQuota(totalMb: j.optionalNumber('totalMb'), remainingMb: j.optionalNumber('remainingMb'), expiresAt: j.optionalString('expiresAt'), capMax: j['capMax'] as bool?);
  final double? totalMb, remainingMb;
  final String? expiresAt;
  final bool? capMax;
}
