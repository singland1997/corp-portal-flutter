import 'package:material_ui/material_ui.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/api/portal_api.dart';
import 'formatters.dart';
import '../../app/theme.dart';

String businessError(BuildContext context, Object? error) {
  if (error is FormatException) return context.tr('The service returned an unsupported response.', 'รูปแบบข้อมูลจากบริการไม่ถูกต้อง');
  if (error is ApiFailure) {
    return switch (error.code) {
      'SOURCE_NOT_SYNCED' => context.tr('Data has not been synchronized yet.', 'ยังไม่ได้ซิงก์ข้อมูลสำหรับองค์กรนี้'),
      'COMMAND_API_UNAVAILABLE' => context.tr('This service operation is not connected yet.', 'ยังไม่ได้เชื่อมต่อบริการสำหรับการดำเนินการนี้'),
      'FORBIDDEN' => context.tr('You do not have permission for this action.', 'คุณไม่มีสิทธิ์ดำเนินการนี้'),
      'CONFLICT' => context.tr('The data has changed or already exists. Refresh and try again.', 'ข้อมูลเปลี่ยนแปลงหรือมีอยู่แล้ว กรุณาโหลดใหม่'),
      _ => context.tr('Unable to complete the request. Please try again.', 'ไม่สามารถดำเนินการได้ กรุณาลองอีกครั้ง'),
    };
  }
  return context.tr('Unable to load data. Please try again.', 'ไม่สามารถโหลดข้อมูลได้ กรุณาลองอีกครั้ง');
}

class BusinessFeedback extends StatelessWidget {
  const BusinessFeedback({super.key, this.loading = false, this.error, this.retry});
  final bool loading;
  final Object? error;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(child: loading ? const CircularProgressIndicator() : Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(error == null ? Icons.inbox_outlined : Icons.error_outline, size: 40),
      const SizedBox(height: 16),
      Text(error == null ? context.tr('No data to display', 'ไม่มีข้อมูลที่จะแสดง') : businessError(context, error), textAlign: TextAlign.center),
      if (retry != null) TextButton(onPressed: retry, child: Text(context.tr('Retry', 'ลองอีกครั้ง'))),
    ])),
  );
}

class BusinessCard extends StatelessWidget {
  const BusinessCard({super.key, required this.child, this.title, this.action});
  final Widget child;
  final String? title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (title != null) ...[Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 12, children: [Text(title!, style: Theme.of(context).textTheme.titleMedium), ?action]), const SizedBox(height: 16)],
    child,
  ])));
}

String statusText(BuildContext context, String? status) => switch (status) {
  'active' => context.tr('Active', 'ใช้งาน'),
  'inactive' => context.tr('Inactive', 'ไม่ใช้งาน'),
  'suspended' => context.tr('Suspended', 'ระงับ'),
  'pending' => context.tr('Pending', 'รอดำเนินการ'),
  'failed' => context.tr('Failed', 'ไม่สำเร็จ'),
  'terminated' => context.tr('Terminated', 'ยกเลิกแล้ว'),
  'accepted' => context.tr('Accepted', 'รับคำขอแล้ว'),
  'rejected' => context.tr('Rejected', 'ปฏิเสธ'),
  'unknown' || null => context.tr('Unknown', 'ไม่ทราบ'),
  _ => status,
};

class BusinessStatus extends StatelessWidget {
  const BusinessStatus(this.value, {super.key});
  final String? value;
  @override
  Widget build(BuildContext context) {
    final color = switch (value) {'active' || 'accepted' => Colors.green, 'failed' || 'rejected' => Colors.red, 'suspended' || 'pending' => Colors.orange, _ => Colors.grey};
    return DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: context.isDark ? .22 : .10), borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Text(statusText(context, value), style: TextStyle(color: context.isDark ? color.shade200 : color.shade800, fontSize: 12))));
  }
}

class DataMetrics extends StatelessWidget {
  const DataMetrics({super.key, required this.items});
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 550 ? 2 : 1;
    final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
    return Wrap(spacing: 12, runSpacing: 12, children: items.map((item) => SizedBox(width: width, child: BusinessCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 12), Text(item.$2, style: Theme.of(context).textTheme.headlineSmall)])))).toList());
  });
}

class FieldDetails extends StatelessWidget {
  const FieldDetails({super.key, required this.items});
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), SelectableText(item.$2)]))).toList());
}

Future<void> showDetails(BuildContext context, String title, List<(String, String)> items) => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text(title), content: SizedBox(width: 480, child: SingleChildScrollView(child: FieldDetails(items: items))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.tr('Close', 'ปิด')))]));

class DateRangeFilters extends StatelessWidget {
  const DateRangeFilters({super.key, this.from, this.to, required this.onChanged});
  final DateTime? from, to;
  final void Function(DateTime? from, DateTime? to) onChanged;
  Future<void> _pick(BuildContext context, bool start) async {
    final selected = await showDatePicker(context: context, initialDate: (start ? from : to) ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (selected != null) onChanged(start ? selected : from, start ? to : selected);
  }
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
    OutlinedButton.icon(onPressed: () => _pick(context, true), icon: const Icon(Icons.calendar_today_outlined), label: Text(from == null ? context.tr('From date', 'ตั้งแต่วันที่') : dateText(from!.toIso8601String(), time: false))),
    OutlinedButton.icon(onPressed: () => _pick(context, false), icon: const Icon(Icons.calendar_today_outlined), label: Text(to == null ? context.tr('To date', 'ถึงวันที่') : dateText(to!.toIso8601String(), time: false))),
    TextButton(onPressed: () => onChanged(null, null), child: Text(context.tr('Clear dates', 'ล้างวันที่'))),
  ]);
}
