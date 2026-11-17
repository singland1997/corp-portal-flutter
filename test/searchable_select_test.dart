import 'package:corp_portal_ui/shared/widgets/searchable_select.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const options = [
  SelectOption('a', 'Test แก้ไข ทดสอบ'),
  SelectOption('b', 'Test crop'),
  SelectOption('c', 'อีโว', subtitle: 'Assigned to: Somchai', enabled: false),
];

Future<Set<String> Function()> pumpSelect(WidgetTester tester, {bool multiple = true, Set<String> initial = const {}}) async {
  var selected = initial;
  late StateSetter rebuild;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(
    padding: const EdgeInsets.all(16),
    child: StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return SearchableSelect(
        label: const Text('Corporates'),
        multiple: multiple,
        options: options,
        selected: selected,
        onChanged: (ids) => rebuild(() => selected = ids),
      );
    }),
  ))));
  return () => selected;
}

void main() {
  testWidgets('search filters the list and multiple picks become chips', (tester) async {
    final selected = await pumpSelect(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corporates'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(3));

    await tester.enterText(find.byType(TextField), 'crop');
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Test crop'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Test แก้ไข ทดสอบ'));
    await tester.pumpAndSettle();
    expect(selected(), {'a', 'b'});

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.widgetWithText(InputChip, 'Test crop'), findsOneWidget);
  });

  testWidgets('an option owned by someone else cannot be picked', (tester) async {
    final selected = await pumpSelect(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corporates'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'อีโว'));
    await tester.pumpAndSettle();
    expect(selected(), isEmpty);
    expect(find.text('Assigned to: Somchai'), findsOneWidget);
  });

  testWidgets('removing a chip unselects it', (tester) async {
    final selected = await pumpSelect(tester, initial: {'a', 'b'});
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.widgetWithText(InputChip, 'Test crop'), matching: find.byTooltip('Remove')));
    await tester.pumpAndSettle();
    expect(selected(), {'a'});
  });

  testWidgets('single choice picks one and closes', (tester) async {
    final selected = await pumpSelect(tester, multiple: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corporates'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'แก้ไข');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Test แก้ไข ทดสอบ'));
    await tester.pumpAndSettle();
    expect(selected(), {'a'});
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Test แก้ไข ทดสอบ'), findsOneWidget);
  });
}
