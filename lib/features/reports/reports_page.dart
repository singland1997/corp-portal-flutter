import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/api/portal_api.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/paged_table.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/download/save_text_file.dart';
import '../../shared/widgets/corporate_scope.dart';
import '../auth/bloc/auth_bloc.dart';
import 'report_definition.dart';
import 'report_format.dart';
import 'reports_bloc.dart';
import 'reports_repository.dart';

const _descriptions = <String, (String, String)>{
  'package-status': ('SIMs on each package across all corporates.', 'จำนวน SIM ในแต่ละแพ็กเกจของทุกองค์กร'),
  'sim-status': ('SIM counts by status for each corporate.', 'จำนวน SIM ตามสถานะของแต่ละองค์กร'),
  'user-activity': ('Sign-ins and changes made by portal users.', 'การเข้าสู่ระบบและการเปลี่ยนแปลงโดยผู้ใช้พอร์ทัล'),
  'usage-summary': ('Daily voice, data and SMS totals for this corporate.', 'ยอดรวมรายวันของโทร ดาต้า และ SMS ขององค์กรนี้'),
  'usage-detail': ('Daily voice, data and SMS per mobile number.', 'การใช้งานรายวันของโทร ดาต้า และ SMS แยกตามเลขหมาย'),
  'sim-activity': ('SIM activations, suspensions and other changes.', 'การเปิดใช้ ระงับ และการเปลี่ยนแปลงอื่นของ SIM'),
  'packages': ('Packages used by this corporate and what they include.', 'แพ็กเกจที่องค์กรใช้และสิทธิ์ที่ได้รับ'),
};

/// Pick a report → optional date range → table → CSV export.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) => CorporateScope(builder: (context, id) {
    final reports = reportsForRole(context.read<AuthBloc>().state.user?.role);
    return BlocProvider(
      create: (_) {
        final bloc = ReportsBloc(ApiReportsRepository(context.read<PortalApi>()), id);
        if (reports.isNotEmpty) bloc.add(ReportsRequested(reports.first));
        return bloc;
      },
      child: _ReportsView(reports: reports),
    );
  });
}

class _ReportsView extends StatefulWidget {
  const _ReportsView({required this.reports});
  final List<ReportDefinition> reports;
  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  List<ReportDefinition> get reports => widget.reports;
  bool _exporting = false;
  int _total = 0;

  static final _isoDate = DateFormat('yyyy-MM-dd');

  /// CSV holds every row of the report, fetched once on demand (the table only has one page).
  Future<void> _export(BuildContext context, ReportsState state) async {
    final bloc = context.read<ReportsBloc>();
    final definition = state.definition!;
    final thai = Localizations.localeOf(context).languageCode == 'th';
    final range = definition.dated && (state.from != null || state.to != null) ? '-${state.from ?? ''}_${state.to ?? ''}' : '';
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.tr('Unable to save the file.', 'ไม่สามารถบันทึกไฟล์ได้');
    setState(() => _exporting = true);
    try {
      final rows = await bloc.repository.load(bloc.corporateId, definition.id, from: state.from, to: state.to);
      await saveTextFile('${definition.id}$range.csv', reportCsv(definition, rows, thai: thai));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ReportsBloc, ReportsState>(builder: (context, state) {
    final bloc = context.read<ReportsBloc>();
    final definition = state.definition;
    final thai = Localizations.localeOf(context).languageCode == 'th';
    void request(ReportDefinition report, {String? from, String? to}) => bloc.add(ReportsRequested(report, from: from, to: to));
    final platform = reports.where((r) => r.platform).toList();
    final corporate = reports.where((r) => !r.platform).toList();
    DropdownMenuItem<String> header(String text) => DropdownMenuItem(enabled: false, value: '__$text', child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
    DropdownMenuItem<String> item(ReportDefinition r) => DropdownMenuItem(value: r.id, child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(thai ? r.th : r.en)));
    final description = definition == null ? null : _descriptions[definition.id];

    return SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(title: context.tr('Reports', 'รายงาน')),
      const SizedBox(height: 20),
      BusinessCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 280, child: DropdownButtonFormField<String>(
            initialValue: definition?.id, isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('Report', 'รายงาน')),
            items: [
              // Sales see these reports only for their assigned corporates (the API applies the scope).
              if (platform.isNotEmpty) header(context.read<AuthBloc>().state.user?.role == 'sales'
                ? context.tr('My assigned corporates', 'องค์กรที่ดูแล')
                : context.tr('All corporates', 'ทุกองค์กร')),
              ...platform.map(item),
              if (corporate.isNotEmpty && platform.isNotEmpty) header(context.tr('Selected corporate', 'องค์กรที่เลือก')),
              ...corporate.map(item),
            ],
            selectedItemBuilder: (context) => [
              if (platform.isNotEmpty) const SizedBox.shrink(),
              ...platform.map((r) => Text(thai ? r.th : r.en)),
              if (corporate.isNotEmpty && platform.isNotEmpty) const SizedBox.shrink(),
              ...corporate.map((r) => Text(thai ? r.th : r.en)),
            ],
            onChanged: (id) {
              final report = reports.where((r) => r.id == id).firstOrNull;
              if (report != null) request(report, from: state.from, to: state.to);
            },
          )),
          if (definition?.dated ?? false) DateRangeFilters(
            from: state.from == null ? null : DateTime.parse(state.from!),
            to: state.to == null ? null : DateTime.parse(state.to!),
            onChanged: (from, to) => request(definition!, from: from == null ? null : _isoDate.format(from), to: to == null ? null : _isoDate.format(to)),
          ),
          OutlinedButton.icon(
            onPressed: _total == 0 || _exporting || state.invalidDates ? null : () => _export(context, state),
            icon: const Icon(Icons.download_outlined),
            label: Text(context.tr('Export CSV', 'ส่งออก CSV')),
          ),
        ]),
        if (definition != null && description != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(
          '${thai ? description.$2 : description.$1}${definition.dated ? '' : ' · ${context.tr('This report shows current figures, so the date range does not apply.', 'รายงานนี้แสดงตัวเลขปัจจุบัน ไม่ใช้ช่วงวันที่')}'}',
          style: Theme.of(context).textTheme.bodySmall,
        )),
        if (state.invalidDates) Padding(padding: const EdgeInsets.only(top: 16), child: Notice(context.tr('The start date must be before the end date.', 'วันที่เริ่มต้องอยู่ก่อนวันที่สิ้นสุด'), kind: NoticeKind.warning)),
      ])),
      const SizedBox(height: 16),
      if (definition != null && !state.invalidDates) BusinessCard(
        title: thai ? definition.th : definition.en,
        child: RemoteTable<ReportRow>(
          // A new report or date range starts again from page 1 with that report's columns.
          key: ValueKey('${definition.id}|${state.from}|${state.to}'),
          load: (q) => bloc.repository.page(bloc.corporateId, definition.id, q, from: state.from, to: state.to),
          initialQuery: PageQuery(sort: definition.columns.first.field, direction: definition.dated ? 'desc' : 'asc'),
          onLoaded: (page) { if (page.total != _total) setState(() => _total = page.total); },
          id: (row) => '${identityHashCode(row)}',
          columns: [
            for (final column in definition.columns) RemoteColumn<ReportRow>(
              thai ? column.th : column.en,
              (row) => Text(reportCell(row.values[column.field], column, thai: thai)),
              sortKey: column.field,
            ),
          ],
        ),
      ),
    ]));
  });

}
