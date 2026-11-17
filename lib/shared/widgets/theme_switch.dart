import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/theme_mode_cubit.dart';

class ThemeSwitch extends StatelessWidget {
  const ThemeSwitch({super.key});
  @override
  Widget build(BuildContext context) => SegmentedButton<ThemeMode>(
    showSelectedIcon: false,
    segments: [
      ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined, size: 18), tooltip: context.tr('Match device', 'ตามอุปกรณ์')),
      ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined, size: 18), tooltip: context.tr('Light', 'สว่าง')),
      ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined, size: 18), tooltip: context.tr('Dark', 'มืด')),
    ],
    selected: {context.watch<ThemeModeCubit>().state},
    onSelectionChanged: (value) => context.read<ThemeModeCubit>().change(value.single),
  );
}
