import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('th'));
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!isClosed) emit(Locale(prefs.getString('portal.locale') == 'en' ? 'en' : 'th'));
  }
  Future<void> change(String language) async {
    emit(Locale(language == 'en' ? 'en' : 'th'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('portal.locale', state.languageCode);
  }
}
extension PortalTranslations on BuildContext {
  String tr(String en, String th) => Localizations.localeOf(this).languageCode == 'th' ? th : en;
}
