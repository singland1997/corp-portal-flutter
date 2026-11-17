import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/portal_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Thai month names for DateFormat(..., 'th').
  await initializeDateFormatting();
  runApp(const PortalApp());
}
