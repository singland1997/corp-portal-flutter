import 'package:intl/intl.dart';

/// Data units follow the CRM: 1 GB = 1024 MB, 1 TB = 1024 GB (1 MB = 1024² bytes).
const mbPerGb = 1024.0;
const mbPerTb = 1024.0 * 1024.0;

String dataSize(double? mb, {bool terabytes = false}) {
  if (mb == null || !mb.isFinite) return '—';
  final absolute = mb.abs();
  final divisor = terabytes && absolute >= mbPerTb ? mbPerTb : absolute >= mbPerGb ? mbPerGb : 1.0;
  final unit = divisor == mbPerTb ? 'TB' : divisor == mbPerGb ? 'GB' : 'MB';
  return '${NumberFormat('#,##0.##').format(mb / divisor)} $unit';
}

String numberText(num? value) => value == null ? '—' : NumberFormat('#,##0.##').format(value);

String dateText(String? value, {bool time = true}) {
  if (value == null) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return '—';
  final bangkok = parsed.toUtc().add(const Duration(hours: 7));
  return DateFormat(time ? 'dd MMM yyyy HH:mm' : 'dd MMM yyyy').format(bangkok);
}

bool inDateRange(String? value, DateTime? from, DateTime? to) {
  if (from == null && to == null) return true;
  final parsed = value == null ? null : DateTime.tryParse(value);
  if (parsed == null) return false;
  final bkk = parsed.toUtc().add(const Duration(hours: 7));
  final date = DateTime(bkk.year, bkk.month, bkk.day);
  return (from == null || !date.isBefore(from)) && (to == null || !date.isAfter(to));
}
