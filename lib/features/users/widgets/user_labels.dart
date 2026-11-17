import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/i18n/locale_cubit.dart';
import '../bloc/user_editor_bloc.dart';
import '../data/user_models.dart';
export '../../../shared/widgets/required_label.dart';

String roleLabel(BuildContext context, UserRole role) => switch (role) {
  UserRole.admin => context.tr('System admin', 'ผู้ดูแลระบบ'),
  UserRole.sales => context.tr('Sales', 'ฝ่ายขาย'),
  UserRole.corporate => context.tr('Corporate admin', 'ผู้ดูแลองค์กร'),
};

String statusLabel(BuildContext context, UserStatus status) => switch (status) {
  UserStatus.active => context.tr('Active', 'ใช้งาน'),
  UserStatus.inactive => context.tr('Inactive', 'ปิดใช้งาน'),
  UserStatus.pending => context.tr('Pending', 'รอตั้งรหัสผ่าน'),
};

String corporateLabel(BuildContext context, UserCorporate corporate) =>
    Localizations.localeOf(context).languageCode == 'th'
    ? corporate.nameTh ?? corporate.name
    : corporate.name;

String userError(BuildContext context, Object error) {
  final code = error is ApiFailure ? error.code
      : error is UserValidationFailure ? error.code : '';
  return switch (code) {
    'REQUIRED' => context.tr('Fill in all required fields (name up to 120 characters).', 'กรอกข้อมูลจำเป็นให้ครบ (ชื่อไม่เกิน 120 ตัวอักษร)'),
    'INVALID_EMAIL' => context.tr('Enter a valid email.', 'กรอกอีเมลให้ถูกต้อง'),
    'CORPORATE_REQUIRED' => context.tr('Select a corporate.', 'กรุณาเลือกองค์กร'),
    'SALES_CORPORATE_REQUIRED' => context.tr('Select at least one assigned corporate.', 'เลือกองค์กรที่ดูแลอย่างน้อยหนึ่งองค์กร'),
    'CORPORATE_ALREADY_ASSIGNED' => context.tr('A selected corporate belongs to another Sales user. Choose an available corporate.', 'องค์กรที่เลือกมีฝ่ายขายคนอื่นดูแลแล้ว กรุณาเลือกองค์กรที่ยังว่าง'),
    'PASSWORD_NOT_SET' => context.tr('This user must set a password before becoming Active.', 'ผู้ใช้นี้ต้องตั้งรหัสผ่านก่อนเปลี่ยนเป็นใช้งาน'),
    'SELF_CHANGE' => context.tr('You cannot change your own role or status.', 'เปลี่ยนบทบาทหรือสถานะของตัวเองไม่ได้'),
    'INVALID_INPUT' => context.tr('Check the details and try again.', 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่'),
    'FORBIDDEN' => context.tr('You do not have permission to manage users.', 'คุณไม่มีสิทธิ์จัดการผู้ใช้'),
    _ when error is ApiFailure && error.status == 409 => context.tr('This email is already in use.', 'อีเมลนี้ถูกใช้แล้ว'),
    _ when error is FormatException || error is TypeError || error is ArgumentError => context.tr('The server returned an unsupported response.', 'รูปแบบข้อมูลจากระบบไม่ถูกต้อง'),
    _ => context.tr('Unable to complete the request. Try again.', 'ไม่สามารถดำเนินการได้ กรุณาลองอีกครั้ง'),
  };
}

