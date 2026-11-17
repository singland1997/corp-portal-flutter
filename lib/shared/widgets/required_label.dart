import 'package:material_ui/material_ui.dart';

/// Form label with a red asterisk for required fields.
class RequiredLabel extends StatelessWidget {
  const RequiredLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
    TextSpan(text: text),
    const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
  ]));
}
