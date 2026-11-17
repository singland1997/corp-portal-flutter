import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/i18n/locale_cubit.dart';

class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});
  @override
  Widget build(BuildContext context) => SegmentedButton<String>(
    showSelectedIcon: false,
    segments: const [ButtonSegment(value: 'th', label: Text('ไทย')), ButtonSegment(value: 'en', label: Text('EN'))],
    selected: {context.watch<LocaleCubit>().state.languageCode},
    onSelectionChanged: (value) => context.read<LocaleCubit>().change(value.single),
  );
}
