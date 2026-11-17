import 'package:material_ui/material_ui.dart';
import '../../app/theme.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/widgets/corporate_scope.dart';

const _endpoints = [
  ('POST', '/auth/sessions'), ('GET', '/auth/me'), ('DELETE', '/auth/sessions/current'),
  ('GET', '/corporates/{id}'), ('GET', '/corporates/{id}/numbers'), ('POST', '/corporates/{id}/numbers/suspend'), ('GET', '/dashboard'),
  ('GET', '/pools'), ('GET', '/pools/members'), ('GET', '/pools/transactions'), ('GET', '/pools/inventory'),
  ('GET', '/pools/page'), ('GET', '/pools/members/page'), ('GET', '/pools/transactions/page'), ('GET', '/reports/{report}/page'),
  ('GET', '/pools/corporate-quota'), ('GET', '/pools/corporate-quota/history/page'), ('GET', '/invoices/page'), ('GET', '/invoices/{id}'),
  ('POST', '/pools'), ('PATCH', '/pools/{id}'), ('POST', '/pools/{id}/quota-adjustments'),
];

class ApiDocsPage extends StatelessWidget {
  const ApiDocsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final sections = [
      (context.tr('Authentication and organization scope', 'การเข้าสู่ระบบและขอบเขตองค์กร'), context.tr(
        'Login returns a 15-minute JWT and the allowed organizations, then opens Dashboard. Corporate accounts access one organization; Admin and Sales can select from their allowed organizations. Access tokens stay in memory. A rotating refresh token in sessionStorage restores the session through the API on reload. Logout revokes the session and clears storage. OTP is not implemented.',
        'Login ส่ง JWT อายุ 15 นาทีและรายชื่อองค์กรที่มีสิทธิ์ แล้วเปิดหน้า Dashboard บัญชีองค์กรเข้าถึงได้หนึ่งองค์กร ส่วน Admin และ Sales เลือกได้จากองค์กรที่ได้รับอนุญาต Access token อยู่ใน memory ส่วน refresh token แบบหมุนเวียนอยู่ใน sessionStorage เพื่อกู้ session ผ่าน API เมื่อรีเฟรช Logout ยกเลิก session และล้าง storage ส่วน OTP ยังไม่ implement')),
      (context.tr('Status & language', 'สถานะและภาษา'), context.tr(
        'Keep stable status codes in API responses: active, inactive, suspended, pending, failed. Translate display text in the UI. Switching language preserves the current route and local page state.',
        'API ควรใช้รหัสสถานะคงที่: active, inactive, suspended, pending, failed แล้วแปลข้อความใน UI การสลับภาษาคงหน้าปัจจุบันและสถานะภายในหน้าไว้')),
      (context.tr('Actions & permissions', 'การดำเนินการและสิทธิ์'), context.tr(
        'Confirm service changes, enforce permissions on the backend, and return per-number results for bulk operations.',
        'ยืนยันก่อนเปลี่ยนบริการ ตรวจสิทธิ์ที่ Backend และส่งผลแยกแต่ละหมายเลขสำหรับงานแบบกลุ่ม')),
      (context.tr('Errors & retries', 'ข้อผิดพลาดและการลองใหม่'), context.tr(
        'Map loading, empty and error states explicitly. Retry fetches on user request. Do not automatically retry state-changing operations without an agreed idempotency contract.',
        'แยกสถานะกำลังโหลด ไม่มีข้อมูล และข้อผิดพลาดอย่างชัดเจน ให้ผู้ใช้กดลองโหลดใหม่ ไม่ส่งคำขอเปลี่ยนข้อมูลซ้ำอัตโนมัติหากยังไม่มีข้อตกลงเรื่อง idempotency')),
      (context.tr('To confirm with backend', 'เรื่องที่ต้องยืนยันกับ Backend'), context.tr(
        'Base URL and API version; authentication/session handling; corporate tenant scope; pagination; units/time zone; export jobs; audit logs; bulk operation limits and idempotency.',
        'Base URL และเวอร์ชัน API, การยืนยันตัวตนและเซสชัน, ขอบเขตองค์กร, การแบ่งหน้า, หน่วยและเขตเวลา, งานส่งออก, บันทึกการทำรายการ, ขีดจำกัดงานแบบกลุ่มและ idempotency')),
    ];
    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title: context.tr('API documentation', 'เอกสาร API')),
      const SizedBox(height: 20),
      Notice(
        context.tr('Local APIs are connected for Login, Dashboard, Corporate and Pooling. Production providers and the remaining modules are still pending.', 'เชื่อม API local สำหรับ Login, Dashboard, Corporate และ Pooling แล้ว ส่วน provider สำหรับระบบจริงและโมดูลอื่นยังอยู่ระหว่างเตรียมการ'),
        title: context.tr('Draft · Backend confirmation required', 'ฉบับร่าง · รอยืนยันจากทีม Backend'),
        kind: NoticeKind.warning,
      ),
      const SizedBox(height: 16),
      BusinessCard(title: context.tr('Connected endpoints', 'Endpoint ที่เชื่อมแล้ว'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr(
          'Base: /api/v1. Business requests send Authorization: Bearer and X-Corporate-ID. The server checks access on every request. Local data is stored on the backend; the frontend has no mock fallback. Request and response contracts are documented in docs/api-integration.md.',
          'Base: /api/v1 คำขอข้อมูลธุรกิจส่ง Authorization: Bearer และ X-Corporate-ID โดยเซิร์ฟเวอร์ตรวจสิทธิ์ทุกครั้ง ข้อมูล local อยู่หลังบ้าน หน้าบ้านไม่มี mock fallback รายละเอียด request/response อยู่ใน docs/api-integration.md'), style: TextStyle(color: context.palette.muted)),
        const SizedBox(height: 12),
        for (final (index, (method, path)) in _endpoints.indexed) ...[
          if (index > 0) const Divider(height: 1),
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
            SizedBox(width: 72, child: Text(method, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700))),
            Expanded(child: SelectableText(path, style: const TextStyle(fontFamily: 'monospace'))),
          ])),
        ],
      ])),
      for (final (title, body) in sections) ...[const SizedBox(height: 16), BusinessCard(title: title, child: Text(body, style: const TextStyle(height: 1.7)))],
    ]));
  }
}
