import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light (the yellow/white brand default), dark or follow the device. Remembered per browser/device.
class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit() : super(ThemeMode.light);
  static const _key = 'portal.theme';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (!isClosed) emit(ThemeMode.values.firstWhere((mode) => mode.name == saved, orElse: () => ThemeMode.light));
  }

  Future<void> change(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
