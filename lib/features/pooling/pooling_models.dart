import '../../shared/business/json_read.dart';
import '../../shared/business/formatters.dart' show mbPerGb;

String _date(Map<String, dynamic> j, String key) {
  final value = j.string(key);
  if (DateTime.tryParse(value) == null) throw FormatException('Invalid date: $key');
  return value;
}

class DataPool {
  const DataPool({required this.id, required this.corporateId, required this.name, required this.corporate, this.lot, required this.status,
    this.quotaMb, this.usedMb, required this.createdAt, required this.createdBy, required this.updatedAt, required this.updatedBy, required this.sourceState});
  factory DataPool.fromJson(Map<String, dynamic> j) => DataPool(
    id: j.string('id'), corporateId: j.string('corporateId'), name: j.string('name'), corporate: j.string('corporate'),
    lot: j.optionalString('lot'), status: j.enumString('status', {'active', 'inactive'}),
    quotaMb: j.optionalNumber('quotaMb'), usedMb: j.optionalNumber('usedMb'),
    createdAt: _date(j, 'createdAt'), createdBy: j.string('createdBy'), updatedAt: _date(j, 'updatedAt'), updatedBy: j.string('updatedBy'),
    sourceState: j.enumString('sourceState', {'unlinked', 'partial', 'complete'}),
  );
  final String id, corporateId, name, corporate, status, createdAt, createdBy, updatedAt, updatedBy, sourceState;
  final String? lot;
  /// `null` = unknown (no verified/unit-mapped source bucket); never treated as 0.
  final double? quotaMb, usedMb;
  double? get remainingMb => quotaMb != null && usedMb != null ? quotaMb! - usedMb! : null;
  int? get percent => quotaMb != null && usedMb != null && quotaMb! > 0 ? (usedMb! / quotaMb! * 100).round() : null;
}

class PoolMember {
  const PoolMember({required this.id, required this.poolId, required this.mobile, this.assignedTo, this.department, this.usedMb, this.status});
  factory PoolMember.fromJson(Map<String, dynamic> j) => PoolMember(
    id: j.string('id'), poolId: j.string('poolId'), mobile: j.string('mobile'), assignedTo: j.optionalString('assignedTo'),
    department: j.optionalString('department'), usedMb: j.optionalNumber('usedMb'), status: j.optionalStatus('status'),
  );
  final String id, poolId, mobile;
  final String? assignedTo, department, status;
  final double? usedMb;
}

class PoolTransaction {
  const PoolTransaction({required this.id, required this.poolId, required this.type, this.occurredAt, this.amountMb, this.totalAfterMb,
    this.remainingAfterMb, this.afterQuantityMb, this.performedBy, this.reason});
  factory PoolTransaction.fromJson(Map<String, dynamic> j) {
    final occurred = j.optionalString('occurredAt');
    if (occurred != null && DateTime.tryParse(occurred) == null) throw const FormatException('Invalid date: occurredAt');
    return PoolTransaction(
      id: j.string('id'), poolId: j.string('poolId'), type: j.string('type'), occurredAt: occurred,
      amountMb: j.optionalNumber('amountMb'), totalAfterMb: j.optionalNumber('totalAfterMb'), remainingAfterMb: j.optionalNumber('remainingAfterMb'),
      afterQuantityMb: j.optionalNumber('afterQuantityMb'), performedBy: j.optionalString('performedBy'), reason: j.optionalString('reason'),
    );
  }
  /// `increase`/`decrease`, or the raw source action when the direction is unknown.
  final String id, poolId, type;
  final String? occurredAt, performedBy, reason;
  final double? amountMb, totalAfterMb, remainingAfterMb;
  /// Source after_quantity; not confirmed as total or remaining.
  final double? afterQuantityMb;
}

class PoolInventoryItem {
  const PoolInventoryItem({required this.id, required this.poolId, this.name, this.status});
  factory PoolInventoryItem.fromJson(Map<String, dynamic> j) => PoolInventoryItem(id: j.string('id'), poolId: j.string('poolId'), name: j.optionalString('name'), status: j.optionalString('status'));
  final String id, poolId;
  final String? name, status;
}

class PoolingSnapshot {
  const PoolingSnapshot({required this.pools, required this.members, required this.inventory, required this.poolWrite, required this.quotaAdjust});
  final List<DataPool> pools;
  final List<PoolMember> members;
  final List<PoolInventoryItem> inventory;
  /// Which commands are connected (GET /pools/capabilities).
  final bool poolWrite, quotaAdjust;
}

class PoolDraft {
  const PoolDraft({this.name = '', this.status = 'active'});
  final String name, status;
}

enum DataUnit { mb, gb }

class QuotaDraft {
  const QuotaDraft({required this.direction, this.amount, this.unit = DataUnit.mb, this.reason = ''});
  final String direction;
  final double? amount;
  final DataUnit unit;
  final String reason;
  /// Signed change in MB.
  double get delta => toMegabytes(amount, unit) * (direction == 'increase' ? 1 : -1);
}

enum PoolError { nameRequired, duplicateName, invalidStatus, invalidAmount, exceedsAvailable, reasonRequired, poolMissing, inactivePool, quotaUnknown }

/// GB input uses the CRM unit: 1 GB = 1024 MB.
double toMegabytes(double? amount, DataUnit unit) => ((amount ?? 0) * (unit == DataUnit.gb ? mbPerGb : 1) * 100).roundToDouble() / 100;

PoolError? quotaError(DataPool pool, QuotaDraft draft) {
  if (pool.status != 'active') return PoolError.inactivePool;
  if (pool.quotaMb == null || pool.usedMb == null) return PoolError.quotaUnknown;
  final amount = toMegabytes(draft.amount, draft.unit);
  if (!amount.isFinite || amount <= 0 || amount > 1000000000) return PoolError.invalidAmount;
  final reason = draft.reason.trim();
  if (reason.isEmpty || reason.length > 200) return PoolError.reasonRequired;
  // Conservative until overage/reduction policy is agreed. Existing negative balances remain visible.
  if (draft.direction == 'decrease' && amount > (pool.quotaMb! - pool.usedMb!).clamp(0, double.infinity)) return PoolError.exceedsAvailable;
  return null;
}

PoolError? poolError(PoolDraft draft, List<DataPool> pools, String? id) {
  final name = draft.name.trim();
  if (name.isEmpty || name.length > 80) return PoolError.nameRequired;
  if (!{'active', 'inactive'}.contains(draft.status)) return PoolError.invalidStatus;
  if (pools.any((p) => p.id != id && p.name.toLowerCase() == name.toLowerCase())) return PoolError.duplicateName;
  if (id != null && !pools.any((p) => p.id == id)) return PoolError.poolMissing;
  return null;
}

/// Bangkok calendar date; rows without a timestamp only match when no date filter is set.
bool matchesPoolDateRange(String? iso, DateTime? from, DateTime? to) {
  if (iso == null) return from == null && to == null;
  final bkk = DateTime.parse(iso).toUtc().add(const Duration(hours: 7));
  final date = DateTime(bkk.year, bkk.month, bkk.day);
  return (from == null || !date.isBefore(from)) && (to == null || !date.isAfter(to));
}
