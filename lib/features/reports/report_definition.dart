enum ReportCellFormat { text, number, data, date, dateTime, label }

class ReportColumn {
  const ReportColumn(this.field, this.en, this.th, [this.format = ReportCellFormat.text]);
  final String field, en, th;
  final ReportCellFormat format;
}

class ReportDefinition {
  const ReportDefinition(this.id, this.en, this.th, this.columns,
      {this.platform = false, this.dated = false});
  final String id, en, th;
  final bool platform, dated;
  final List<ReportColumn> columns;
}

const _date = ReportColumn('date', 'Date', 'วันที่', ReportCellFormat.date);
const _time = ReportColumn('date', 'Date / time', 'วันที่ / เวลา', ReportCellFormat.dateTime);
const _corporate = ReportColumn('corporate', 'Corporate', 'องค์กร');
const _package = ReportColumn('package', 'Package', 'แพ็กเกจ');
const _mobile = ReportColumn('mobile', 'Mobile number', 'เลขหมาย');
const _sims = ReportColumn('sims', 'SIMs', 'SIM', ReportCellFormat.number);
const _active = ReportColumn('activeSims', 'Active SIMs', 'SIM ที่ใช้งาน', ReportCellFormat.number);
const _voice = ReportColumn('voiceMinutes', 'Voice (min)', 'โทร (นาที)', ReportCellFormat.number);
const _data = ReportColumn('dataMb', 'Data', 'ดาต้า', ReportCellFormat.data);
const _sms = ReportColumn('sms', 'SMS', 'SMS', ReportCellFormat.number);
const _status = ReportColumn('status', 'Status', 'สถานะ', ReportCellFormat.label);

const reportDefinitions = <ReportDefinition>[
  ReportDefinition('package-status', 'Package status', 'สถานะแพ็กเกจ', [
    _package, _corporate, _sims, _active,
    ReportColumn('suspendedSims', 'Suspended SIMs', 'SIM ที่ระงับ', ReportCellFormat.number), _status,
  ], platform: true),
  ReportDefinition('sim-status', 'SIM status', 'สถานะ SIM', [
    _corporate, ReportColumn('lot', 'Corporate lot', 'Lot องค์กร'),
    ReportColumn('total', 'Total', 'ทั้งหมด', ReportCellFormat.number),
    ReportColumn('active', 'Active', 'ใช้งาน', ReportCellFormat.number),
    ReportColumn('inactive', 'Inactive', 'ไม่ใช้งาน', ReportCellFormat.number),
    ReportColumn('suspended', 'Suspended', 'ระงับ', ReportCellFormat.number),
    ReportColumn('terminated', 'Terminated', 'ยกเลิกแล้ว', ReportCellFormat.number),
    ReportColumn('unknownStatus', 'Status unknown', 'ไม่ทราบสถานะ', ReportCellFormat.number),
  ], platform: true),
  ReportDefinition('user-activity', 'User activity', 'กิจกรรมผู้ใช้', [
    _time, ReportColumn('user', 'User', 'ผู้ใช้'), ReportColumn('email', 'Email', 'อีเมล'),
    _corporate, ReportColumn('action', 'Action', 'การกระทำ'),
    ReportColumn('result', 'Result', 'ผลลัพธ์', ReportCellFormat.label),
  ], platform: true, dated: true),
  ReportDefinition('usage-summary', 'Usage summary', 'สรุปการใช้งาน', [_date, _voice, _data, _sms], dated: true),
  ReportDefinition('usage-detail', 'Detailed usage', 'การใช้งานรายละเอียด', [
    _date, _mobile, ReportColumn('owner', 'Assigned to', 'ผู้ใช้งาน'), _voice, _data, _sms,
  ], dated: true),
  ReportDefinition('sim-activity', 'SIM activity', 'กิจกรรม SIM', [
    _time, _mobile, ReportColumn('activity', 'Activity', 'กิจกรรม'), _status,
    ReportColumn('performedBy', 'Performed by', 'ดำเนินการโดย'),
  ], dated: true),
  ReportDefinition('packages', 'Packages', 'แพ็กเกจ', [
    _package, _sims, _active,
    ReportColumn('dataMb', 'Data allowance', 'โควตาดาต้า', ReportCellFormat.data), _voice, _sms,
    ReportColumn('monthlyFeeThb', 'Monthly fee (THB)', 'ค่าบริการรายเดือน (บาท)', ReportCellFormat.number),
  ]),
];

List<ReportDefinition> reportsForRole(String? role) => reportDefinitions
    .where((r) => !r.platform || role == 'admin' || role == 'sales').toList(growable: false);
