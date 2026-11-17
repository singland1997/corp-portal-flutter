import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/theme.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/business/business_widgets.dart';
import '../../shared/widgets/corporate_scope.dart';
import '../../shared/widgets/required_label.dart';
import 'pooling_cubit.dart';
import 'pooling_models.dart';
import 'pooling_text.dart';

/// Create (pool == null) or edit a pool. Pops `true` when saved.
class PoolFormDialog extends StatefulWidget {
  const PoolFormDialog({super.key, this.pool, required this.corporateName});
  final DataPool? pool;
  final String corporateName;
  @override
  State<PoolFormDialog> createState() => _PoolFormDialogState();
}

class _PoolFormDialogState extends State<PoolFormDialog> {
  late final _name = TextEditingController(text: widget.pool?.name ?? '');
  late String _status = widget.pool?.status ?? 'active';
  PoolError? _error;
  @override
  void initState() { super.initState(); context.read<PoolingCubit>().clearMutationError(); }
  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    final cubit = context.read<PoolingCubit>();
    try {
      final error = await cubit.savePool(PoolDraft(name: _name.text, status: _status), id: widget.pool?.id);
      if (!mounted) return;
      setState(() => _error = error);
      if (error == null) Navigator.pop(context, true);
    } catch (_) { /* mutationError is shown in the form. */ }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PoolingCubit>().state;
    final edit = widget.pool != null;
    return PopScope(canPop: !state.busy, child: AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text(edit ? context.tr('Edit pool', 'แก้ไขพูล') : context.tr('Create pool', 'สร้างพูล')),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(edit ? context.tr('Review the pool name and status before saving.', 'ตรวจสอบชื่อและสถานะพูลก่อนบันทึก') : context.tr('A new pool starts with zero quota. Add quota after creating it.', 'พูลใหม่เริ่มต้นด้วยโควตา 0 สามารถเพิ่มโควตาได้หลังสร้าง'), style: TextStyle(color: context.palette.muted)),
        const SizedBox(height: 16),
        TextField(controller: _name, maxLength: 80, readOnly: state.busy, decoration: InputDecoration(label: RequiredLabel(context.tr('Pool name', 'ชื่อพูล')))),
        const SizedBox(height: 8),
        InputDecorator(decoration: InputDecoration(label: RequiredLabel(context.tr('Corporate', 'บริษัท')), helperText: context.tr('Pools belong to your current corporate account.', 'พูลอยู่ภายใต้บัญชีบริษัทปัจจุบันของคุณ')), child: Text(widget.pool?.corporate ?? widget.corporateName)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _status, isExpanded: true,
          decoration: InputDecoration(label: RequiredLabel(context.tr('Status', 'สถานะ'))),
          items: [for (final s in ['active', 'inactive']) DropdownMenuItem(value: s, child: Text(poolStatusText(context, s)))],
          onChanged: state.busy ? null : (value) => setState(() => _status = value!),
        ),
        if (state.mutationError != null) ...[const SizedBox(height: 16), Notice(businessError(context, state.mutationError), kind: NoticeKind.error)],
        if (_error != null) ...[const SizedBox(height: 16), Notice(poolErrorText(context, _error!), kind: NoticeKind.error)],
      ]))),
      actions: [
        TextButton(onPressed: state.busy ? null : () => Navigator.pop(context, false), child: Text(context.tr('Cancel', 'ยกเลิก'))),
        FilledButton(
          onPressed: state.busy ? null : _save,
          child: state.busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(edit ? context.tr('Save changes', 'บันทึกการเปลี่ยนแปลง') : context.tr('Create pool', 'สร้างพูล')),
        ),
      ],
    ));
  }
}

/// Two steps: enter amount and reason → review → confirm. Pops `true` when adjusted.
class QuotaDialog extends StatefulWidget {
  const QuotaDialog({super.key, required this.poolId, required this.direction});
  final String poolId;
  final String direction;
  @override
  State<QuotaDialog> createState() => _QuotaDialogState();
}

class _QuotaDialogState extends State<QuotaDialog> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  DataUnit _unit = DataUnit.mb;
  bool _review = false;
  PoolError? _error;
  @override
  void initState() { super.initState(); context.read<PoolingCubit>().clearMutationError(); }
  @override
  void dispose() { _amount.dispose(); _reason.dispose(); super.dispose(); }

  QuotaDraft get _draft => QuotaDraft(direction: widget.direction, amount: double.tryParse(_amount.text.replaceAll(',', '').trim()), unit: _unit, reason: _reason.text);

  void _toReview(DataPool? pool) {
    final error = pool == null ? PoolError.poolMissing : quotaError(pool, _draft);
    setState(() { _error = error; _review = error == null; });
  }

  Future<void> _confirm() async {
    final cubit = context.read<PoolingCubit>();
    try {
      final error = await cubit.adjustQuota(widget.poolId, _draft);
      if (!mounted) return;
      setState(() { _error = error; if (error != null) _review = false; });
      if (error == null) Navigator.pop(context, true);
    } catch (_) { /* mutationError is shown in the dialog. */ }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PoolingCubit>().state;
    final pool = state.pools.where((p) => p.id == widget.poolId).firstOrNull;
    final draft = _draft;
    Widget row(String label, String value, {bool strong = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Expanded(child: Text(label)),
      Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w600 : FontWeight.w400)),
    ]));
    return PopScope(canPop: !state.busy, child: AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text(_review ? context.tr('Review quota change', 'ตรวจสอบการปรับโควตา') : transactionType(context, widget.direction)),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: pool == null ? Notice(poolErrorText(context, PoolError.poolMissing), kind: NoticeKind.error) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(pool.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('${pool.corporate} · ${pool.lot ?? '—'}', style: TextStyle(fontSize: 13, color: context.palette.muted)),
        const SizedBox(height: 16),
        if (!_review) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.palette.subtle, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(child: FieldDetails(items: [(context.tr('Total quota', 'โควตารวม'), poolData(pool.quotaMb))])),
              Expanded(child: FieldDetails(items: [(context.tr('Remaining data', 'ข้อมูลคงเหลือ'), poolData(pool.remainingMb))])),
            ]),
          ),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(label: RequiredLabel(context.tr('Data amount', 'จำนวนข้อมูล'))),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<DataUnit>(
              initialValue: _unit, isExpanded: true,
              decoration: InputDecoration(labelText: context.tr('Unit', 'หน่วย')),
              items: const [DropdownMenuItem(value: DataUnit.mb, child: Text('MB')), DropdownMenuItem(value: DataUnit.gb, child: Text('GB'))],
              onChanged: (value) => setState(() => _unit = value!),
            )),
          ]),
          const SizedBox(height: 6),
          Text('1 GB = 1,000 MB', style: TextStyle(fontSize: 12, color: context.palette.muted)),
          const SizedBox(height: 16),
          TextField(controller: _reason, maxLines: 3, maxLength: 200, decoration: InputDecoration(label: RequiredLabel(context.tr('Reason', 'เหตุผล')), hintText: context.tr('Describe the allocation change', 'ระบุเหตุผลในการปรับโควตา'))),
        ] else Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: context.palette.border), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            row(context.tr('Change', 'จำนวนที่ปรับ'), '${draft.delta > 0 ? '+' : ''}${poolData(draft.delta)}', strong: true),
            row('${context.tr('Total quota', 'โควตารวม')} · ${context.tr('Before', 'ก่อนปรับ')}', poolData(pool.quotaMb)),
            row('${context.tr('Total quota', 'โควตารวม')} · ${context.tr('After', 'หลังปรับ')}', poolData(pool.quotaMb == null ? null : pool.quotaMb! + draft.delta), strong: true),
            row('${context.tr('Remaining data', 'ข้อมูลคงเหลือ')} · ${context.tr('After', 'หลังปรับ')}', poolData(pool.remainingMb == null ? null : pool.remainingMb! + draft.delta), strong: true),
            const SizedBox(height: 8),
            FieldDetails(items: [(context.tr('Reason', 'เหตุผล'), draft.reason.trim())]),
          ]),
        ),
        if (state.mutationError != null) ...[const SizedBox(height: 16), Notice(businessError(context, state.mutationError), kind: NoticeKind.error)],
        if (_error != null) ...[const SizedBox(height: 16), Notice(poolErrorText(context, _error!), kind: NoticeKind.error)],
      ]))),
      actions: [
        TextButton(onPressed: state.busy ? null : () => Navigator.pop(context, false), child: Text(context.tr('Cancel', 'ยกเลิก'))),
        if (_review) ...[
          OutlinedButton(onPressed: state.busy ? null : () => setState(() => _review = false), child: Text(context.tr('Back to edit', 'กลับไปแก้ไข'))),
          FilledButton(
            onPressed: state.busy ? null : _confirm,
            child: state.busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(context.tr('Confirm change', 'ยืนยันการปรับ')),
          ),
        ] else FilledButton(onPressed: pool == null ? null : () => _toReview(pool), child: Text(context.tr('Review change', 'ตรวจสอบรายการ'))),
      ],
    ));
  }
}
