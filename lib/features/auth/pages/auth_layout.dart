import 'package:material_ui/material_ui.dart';
import '../../../app/theme.dart';
import '../../../core/i18n/locale_cubit.dart';
import '../../../shared/widgets/language_switch.dart';
import '../../../shared/widgets/theme_switch.dart';
import '../../../shared/widgets/portal_footer.dart';

/// Centered card layout for guest pages (Angular `auth-layout`).
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16, runSpacing: 12,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            ClipOval(child: Image.asset('assets/images/logo.png', width: 32, height: 32)),
            const SizedBox(width: 10),
            const Text('Corp Portal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ]),
          const Wrap(spacing: 8, runSpacing: 8, children: [LanguageSwitch(), ThemeSwitch()]),
        ],
      ))),
      Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 48, height: 48, decoration: BoxDecoration(color: context.palette.primarySoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon))),
          const SizedBox(height: 12),
          Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(24), child: child)),
        ]),
      )))),
      const PortalFooter(),
    ])),
  );
}

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.label, this.autofillHints, this.readOnly = false, this.validator, this.helperText, this.onSubmitted});
  final TextEditingController controller;
  final Widget label;
  final Iterable<String>? autofillHints;
  final bool readOnly;
  final String? Function(String?)? validator;
  final String? helperText;
  final VoidCallback? onSubmitted;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: !_visible,
    readOnly: widget.readOnly,
    autofillHints: widget.autofillHints,
    validator: widget.validator,
    onFieldSubmitted: (_) => widget.onSubmitted?.call(),
    decoration: InputDecoration(
      label: widget.label,
      helperText: widget.helperText,
      suffixIcon: IconButton(
        tooltip: _visible ? context.tr('Hide password', 'ซ่อนรหัสผ่าน') : context.tr('Show password', 'แสดงรหัสผ่าน'),
        isSelected: _visible,
        icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: () => setState(() => _visible = !_visible),
      ),
    ),
  );
}
