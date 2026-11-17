import 'package:material_ui/material_ui.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/formatters.dart';
import 'pooling_models.dart';

/// Unknown stays "—"; values up to TB (pool totals) or GB (members, transactions).
String poolData(double? mb, {bool terabytes = true}) => dataSize(mb, terabytes: terabytes);

String poolErrorText(BuildContext context, PoolError error) => switch (error) {
  PoolError.nameRequired => context.tr('Enter a pool name of 1–80 characters.', 'กรอกชื่อพูล 1–80 ตัวอักษร'),
  PoolError.duplicateName => context.tr('A pool with this name already exists.', 'มีชื่อพูลนี้อยู่แล้ว'),
  PoolError.invalidStatus => context.tr('Select Active or Inactive.', 'เลือกสถานะใช้งานหรือไม่ใช้งาน'),
  PoolError.invalidAmount => context.tr('Enter an amount greater than 0, up to 1,000,000,000 MB.', 'กรอกจำนวนมากกว่า 0 และไม่เกิน 1,000,000,000 MB'),
  PoolError.exceedsAvailable => context.tr('The reduction cannot exceed the available data.', 'จำนวนที่ลดต้องไม่เกินข้อมูลคงเหลือ'),
  PoolError.reasonRequired => context.tr('Enter a reason of 1–200 characters.', 'กรอกเหตุผล 1–200 ตัวอักษร'),
  PoolError.poolMissing => context.tr('This pool could not be found.', 'ไม่พบพูลนี้'),
  PoolError.inactivePool => context.tr('Activate the pool before changing its quota.', 'เปิดใช้งานพูลก่อนปรับโควตา'),
  PoolError.quotaUnknown => context.tr('The pool quota is unknown, so it cannot be adjusted here.', 'ยังไม่ทราบโควตาของพูลนี้ จึงปรับโควตาที่นี่ไม่ได้'),
};

String poolStatusText(BuildContext context, String status) => status == 'active' ? context.tr('Active', 'ใช้งาน') : context.tr('Inactive', 'ไม่ใช้งาน');

String transactionType(BuildContext context, String type) => switch (type) {
  'increase' => context.tr('Increase quota', 'เพิ่มโควตา'),
  'decrease' => context.tr('Decrease quota', 'ลดโควตา'),
  _ => type,
};

/// Fixture department keys have translations; other names are shown as stored.
String departmentText(BuildContext context, String? department) => switch (department) {
  null || '' => context.tr('Not assigned', 'ยังไม่กำหนด'),
  'field' => context.tr('Field operations', 'ปฏิบัติการภาคสนาม'),
  'logistics' => context.tr('Logistics', 'โลจิสติกส์'),
  'sales' => context.tr('Sales', 'ฝ่ายขาย'),
  'other' => context.tr('Other departments', 'แผนกอื่น'),
  _ => department,
};
