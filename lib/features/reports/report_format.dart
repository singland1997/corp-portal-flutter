import 'package:intl/intl.dart';
import '../../shared/business/formatters.dart' show mbPerGb;
import 'report_definition.dart';
import 'reports_repository.dart';

String reportCell(Object? value, ReportColumn column, {required bool thai}) {
  if (value == null || value == '') return '—';
  final locale = thai ? 'th_TH' : 'en_US';
  switch (column.format) {
    case ReportCellFormat.number:
      return value is num ? NumberFormat('#,##0.######', locale).format(value) : '$value';
    case ReportCellFormat.data:
      if (value is! num) return '$value';
      final gb = value.abs() >= mbPerGb;
      return '${NumberFormat('#,##0.##', locale).format(gb ? value / mbPerGb : value)} ${gb ? 'GB' : 'MB'}';
    case ReportCellFormat.date:
    case ReportCellFormat.dateTime:
      final parsed = DateTime.tryParse('$value');
      if (parsed == null) return '$value';
      final date = column.format == ReportCellFormat.dateTime
          ? parsed.toUtc().add(const Duration(hours: 7)) : parsed;
      return DateFormat(column.format == ReportCellFormat.dateTime ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy').format(date);
    case ReportCellFormat.label:
      final labels = <String, (String, String)>{
        'active': ('Active', 'ใช้งาน'), 'inactive': ('Inactive', 'ไม่ใช้งาน'),
        'suspended': ('Suspended', 'ระงับ'), 'pending': ('Pending', 'รอดำเนินการ'),
        'failed': ('Failed', 'ไม่สำเร็จ'), 'terminated': ('Terminated', 'ยกเลิกแล้ว'), 'completed': ('Completed', 'สำเร็จ'),
        'success': ('Success', 'สำเร็จ'), 'denied': ('Denied', 'ถูกปฏิเสธ'),
        'accepted': ('Accepted', 'รับคำขอแล้ว'), 'rejected': ('Rejected', 'ถูกปฏิเสธ'),
        'unknown': ('Unknown', 'ไม่ทราบ'),
      };
      final label = labels[value];
      return label == null ? '$value' : thai ? label.$2 : label.$1;
    case ReportCellFormat.text: return '$value';
  }
}

/// Neutralize formula input, including leading whitespace, before CSV quoting.
String csvCell(String value) {
  final dangerous = RegExp(r'^\s*[=+@-]').hasMatch(value) || value.startsWith('\t') || value.startsWith('\r');
  final safe = dangerous ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}
String reportCsv(ReportDefinition definition, List<ReportRow> rows, {required bool thai}) {
  final lines = <List<String>>[
    definition.columns.map((c) => thai ? c.th : c.en).toList(),
    ...rows.map((row) => definition.columns.map((c) => reportCell(row.values[c.field], c, thai: thai)).toList()),
  ];
  return '\uFEFF${lines.map((line) => line.map(csvCell).join(',')).join('\r\n')}\r\n';
}
