import 'package:material_ui/material_ui.dart';
import '../../core/i18n/locale_cubit.dart';

/// One choice in a [SearchableSelect]. A disabled option is shown but cannot be picked
/// (it can still be removed when already selected).
class SelectOption {
  const SelectOption(this.value, this.label, {this.subtitle, this.enabled = true});
  final String value, label;
  final String? subtitle;
  final bool enabled;
}

/// Form field that opens a dropdown with a search box. Single choice closes on pick;
/// [multiple] shows checkboxes and the picked values as removable chips.
class SearchableSelect extends StatefulWidget {
  const SearchableSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.label,
    this.multiple = false,
    this.enabled = true,
    this.emptyText,
  });
  final List<SelectOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final Widget label;
  final bool multiple, enabled;
  /// Shown when there are no options at all.
  final String? emptyText;

  @override
  State<SearchableSelect> createState() => _SearchableSelectState();
}

class _SearchableSelectState extends State<SearchableSelect> {
  final _menu = MenuController();

  void _toggleMenu() {
    if (!widget.enabled) return;
    _menu.isOpen ? _menu.close() : _menu.open();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final chosen = [for (final option in widget.options) if (widget.selected.contains(option.value)) option];
    return MenuAnchor(
      controller: _menu,
      onOpen: () => setState(() {}),
      onClose: () => setState(() {}),
      style: const MenuStyle(padding: WidgetStatePropertyAll(EdgeInsets.zero)),
      menuChildren: [
        _SelectPanel(
          width: constraints.maxWidth,
          options: widget.options,
          selected: widget.selected,
          multiple: widget.multiple,
          emptyText: widget.emptyText,
          onChanged: widget.onChanged,
          onDone: _menu.close,
        ),
      ],
      builder: (context, menu, _) => Semantics(
        button: true,
        expanded: menu.isOpen,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.enabled ? _toggleMenu : null,
          child: InputDecorator(
            isEmpty: chosen.isEmpty,
            isFocused: menu.isOpen,
            decoration: InputDecoration(
              label: widget.label,
              enabled: widget.enabled,
              suffixIcon: Icon(menu.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
            ),
            child: chosen.isEmpty
                ? const SizedBox(height: 20)
                : widget.multiple
                    ? Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final option in chosen) InputChip(
                          label: Text(option.label),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          deleteButtonTooltipMessage: context.tr('Remove', 'นำออก'),
                          onDeleted: widget.enabled ? () => widget.onChanged({...widget.selected}..remove(option.value)) : null,
                        ),
                      ])
                    : Text(chosen.first.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  });
}

class _SelectPanel extends StatefulWidget {
  const _SelectPanel({
    required this.width, required this.options, required this.selected, required this.multiple,
    required this.onChanged, required this.onDone, this.emptyText,
  });
  final double width;
  final List<SelectOption> options;
  final Set<String> selected;
  final bool multiple;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onDone;
  final String? emptyText;

  @override
  State<_SelectPanel> createState() => _SelectPanelState();
}

class _SelectPanelState extends State<_SelectPanel> {
  final _search = TextEditingController();
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  void _pick(SelectOption option) {
    if (widget.multiple) {
      final ids = {...widget.selected};
      ids.contains(option.value) ? ids.remove(option.value) : ids.add(option.value);
      widget.onChanged(ids);
    } else {
      widget.onChanged({option.value});
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final shown = widget.options.where((o) =>
        query.isEmpty || o.label.toLowerCase().contains(query) || (o.subtitle?.toLowerCase().contains(query) ?? false)).toList();
    return SizedBox(width: widget.width, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: _search,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.tr('Search', 'ค้นหา'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty ? null : IconButton(
              tooltip: context.tr('Clear', 'ล้าง'),
              icon: const Icon(Icons.close),
              onPressed: () => setState(_search.clear),
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            // Enter picks the only match, the quickest path for a long list.
            final enabled = shown.where((o) => o.enabled).toList();
            if (enabled.length == 1) _pick(enabled.single);
          },
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.options.isEmpty
                    ? widget.emptyText ?? context.tr('No options', 'ไม่มีตัวเลือก')
                    : context.tr('No matches', 'ไม่พบรายการที่ค้นหา')),
              )
            // MenuAnchor measures intrinsic width, which ListView cannot report.
            : SingleChildScrollView(primary: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final option in shown)
                  if (widget.multiple)
                    CheckboxListTile(
                      value: widget.selected.contains(option.value),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(option.label),
                      subtitle: option.subtitle == null ? null : Text(option.subtitle!),
                      // A disabled option that is already selected can still be removed.
                      onChanged: option.enabled || widget.selected.contains(option.value) ? (_) => _pick(option) : null,
                    )
                  else
                    ListTile(
                      dense: true,
                      enabled: option.enabled,
                      selected: widget.selected.contains(option.value),
                      title: Text(option.label),
                      subtitle: option.subtitle == null ? null : Text(option.subtitle!),
                      trailing: widget.selected.contains(option.value) ? const Icon(Icons.check, size: 18) : null,
                      onTap: () => _pick(option),
                    ),
              ])),
      ),
      if (widget.multiple) ...[
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(child: Text('${widget.selected.length} ${context.tr('selected', 'รายการที่เลือก')}', style: Theme.of(context).textTheme.bodySmall)),
            TextButton(onPressed: widget.onDone, child: Text(context.tr('Done', 'เสร็จ'))),
          ]),
        ),
      ],
    ]));
  }
}
