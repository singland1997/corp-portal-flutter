import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/portal_api.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../shared/widgets/corporate_scope.dart';
import '../../shared/business/business_widgets.dart';
import '../corporate/corporate_repository.dart';
import '../corporate/number_table.dart';

/// SIM list of the selected corporate, paged by the API (same SQL page as Corporate numbers).
class SimPage extends StatefulWidget {
  const SimPage({super.key});
  @override
  State<SimPage> createState() => _SimPageState();
}

class _SimPageState extends State<SimPage> {
  late final _repository = ApiCorporateRepository(context.read<PortalApi>());
  int _revision = 0;
  @override
  Widget build(BuildContext context) => CorporateScope(builder: (context, id) => SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Wrap(alignment: WrapAlignment.spaceBetween, children: [
      Text(context.tr('SIM & service management', 'จัดการซิมและบริการ'), style: Theme.of(context).textTheme.headlineMedium),
      IconButton(tooltip: context.tr('Refresh', 'โหลดใหม่'), onPressed: () => setState(() => _revision++), icon: const Icon(Icons.refresh)),
    ]),
    const SizedBox(height: 20),
    BusinessCard(child: NumberTable(key: ValueKey('$id:$_revision'), load: (q) => _repository.numbers(id, q))),
  ])));
}
