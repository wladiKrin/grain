import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/gear/ui/body_picker.dart';
import 'package:grain/gear/ui/lens_picker.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/gear_fixtures.dart';

late GearController gear;

/// Opens [screen] on top of a home route so popping is observable.
Future<void> open(WidgetTester t, Widget Function() screen) async {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: grainTheme(),
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<void>(
              c,
              MaterialPageRoute(builder: (_) => screen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

double y(WidgetTester t, Finder f) => t.getTopLeft(f.first).dy;

Future<void> tapAction(WidgetTester t, String tile, String action) async {
  final row = find.ancestor(
    of: find.text(tile).first,
    matching: find.byType(InkWell),
  );
  await t.tap(
    find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert)),
  );
  await t.pumpAndSettle();
  await t.tap(find.text(action));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => gear = GearController.inMemory(library: fixtureLibrary()));

  testWidgets('No camera is first, favorites before all', (t) async {
    await gear.toggleFavorite(libBody('pentax-k1000'));
    await open(t, () => BodyPickerScreen(gear: gear));
    expect(find.text('Library'), findsOneWidget);
    final order = [
      y(t, find.text('No camera')),
      y(t, find.text('Favorites')),
      y(t, find.text('Pentax K1000')),
      y(t, find.text('All')),
    ];
    expect(order, [...order]..sort());
    expect(order.toSet().length, 4);
    // The favorite also stays in its make group under All.
    expect(find.text('Pentax K1000'), findsNWidgets(2));
    // No camera is selected at the start.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('star toggles a favorite', (t) async {
    final semantics = t.ensureSemantics();
    await open(t, () => BodyPickerScreen(gear: gear));
    final a1 = libBody('canon-a1');
    expect(gear.isFavorite(a1), isFalse);
    final row = find.ancestor(
      of: find.text('Canon A-1'),
      matching: find.byType(InkWell),
    );
    await t.tap(
      find.descendant(of: row.first, matching: find.byIcon(Icons.star_border)),
    );
    await t.pumpAndSettle();
    expect(gear.isFavorite(a1), isTrue);
    expect(find.bySemanticsLabel('Remove from favorites'), findsWidgets);
    expect(t.getSize(find.byTooltip('Remove from favorites').first).height, 44);
    semantics.dispose();
  });

  testWidgets('tapping a body selects it and pops', (t) async {
    await open(t, () => BodyPickerScreen(gear: gear));
    await t.tap(find.text('Canon A-1'));
    await t.pumpAndSettle();
    expect(gear.body?.id, 'canon-a1');
    expect(find.text('Library'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('tapping No camera clears the body', (t) async {
    await gear.selectBody(libBody('canon-a1'));
    await open(t, () => BodyPickerScreen(gear: gear));
    await t.tap(find.text('No camera'));
    await t.pumpAndSettle();
    expect(gear.body, isNull);
    expect(find.text('Library'), findsNothing);
  });

  testWidgets('lens picker lists only the mount, favorites first', (t) async {
    await gear.selectBody(libBody('canon-a1'));
    await gear.toggleFavorite(libLens('canon-fd-135-3.5'));
    await open(t, () => LensPickerScreen(gear: gear, mount: 'canon-fd'));
    expect(find.text('No lens'), findsOneWidget);
    expect(find.textContaining('Nikkor'), findsNothing);
    expect(find.textContaining('AI-S'), findsNothing);
    // 5 lenses, one of them listed again under Favorites.
    expect(find.textContaining('FD '), findsNWidgets(6));
    expect(
      y(t, find.text('Favorites')),
      lessThan(y(t, find.text('FD 135mm f/3.5'))),
    );
    expect(y(t, find.text('FD 135mm f/3.5')), lessThan(y(t, find.text('All'))));
    // All is in focal order: 28 before 50 before 135.
    expect(
      y(t, find.text('FD 28mm f/2.8')),
      lessThan(y(t, find.text('FD 50mm f/1.4'))),
    );
    await t.tap(find.text('FD 50mm f/1.8'));
    await t.pumpAndSettle();
    expect(gear.lens?.id, 'canon-fd-50-1.8');
  });

  testWidgets('empty mount offers to create a lens', (t) async {
    await open(t, () => LensPickerScreen(gear: gear, mount: 'none'));
    expect(find.text('No lenses for this mount yet.'), findsOneWidget);
    await t.tap(find.text('Create lens'));
    await t.pumpAndSettle();
    expect(find.text('New lens'), findsOneWidget);
  });

  testWidgets('duplicate and edit opens a prefilled copy', (t) async {
    await open(t, () => BodyPickerScreen(gear: gear));
    final a1 = libBody('canon-a1');
    await tapAction(t, 'Canon A-1', 'Duplicate and edit');
    expect(find.text('New body'), findsOneWidget);
    expect(find.text('A-1 (copy)'), findsOneWidget);
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final copy = gear.bodies.singleWhere((b) => b.id == 'canon-a-1-copy');
    expect(gear.isUser(copy), isTrue);
    expect(find.text('Canon A-1 (copy)'), findsOneWidget);
    expect(find.text('Yours'), findsOneWidget);
    expect(gear.bodies.firstWhere((b) => b.id == 'canon-a1'), a1);
    expect(gear.isUser(a1), isFalse);
  });

  testWidgets('deleting the selected user body returns to No camera', (
    t,
  ) async {
    final copy = await gear.saveUser(gear.duplicateBody(libBody('canon-a1')));
    await gear.selectBody(copy);
    await open(t, () => BodyPickerScreen(gear: gear));
    await tapAction(t, 'Canon A-1 (copy)', 'Delete');
    expect(find.text('Delete Canon A-1 (copy)?'), findsOneWidget);
    await t.tap(find.text('Delete').last);
    await t.pumpAndSettle();
    expect(gear.body, isNull);
    expect(gear.lens, isNull);
    expect(gear.bodies.any((b) => b.id == copy.id), isFalse);
    expect(find.text('Canon A-1 (copy)'), findsNothing);
    expect(t.takeException(), isNull);
    // The check mark moved back to No camera.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog keeps the body', (t) async {
    final copy = await gear.saveUser(gear.duplicateBody(libBody('canon-a1')));
    await open(t, () => BodyPickerScreen(gear: gear));
    await tapAction(t, 'Canon A-1 (copy)', 'Delete');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(gear.isUser(copy), isTrue);
  });

  testWidgets('bundled profiles offer no Edit or Delete', (t) async {
    await open(t, () => BodyPickerScreen(gear: gear));
    final row = find.ancestor(
      of: find.text('Canon A-1'),
      matching: find.byType(InkWell),
    );
    await t.tap(
      find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert)),
    );
    await t.pumpAndSettle();
    expect(find.text('Duplicate and edit'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('user profiles offer Edit and Delete; share only when wired', (
    t,
  ) async {
    await gear.saveUser(gear.duplicateBody(libBody('canon-a1')));
    await gear.toggleFavorite(libLens('canon-fd-50-1.8'));
    final shared = <GearDoc>[];
    await open(t, () => BodyPickerScreen(gear: gear, onShare: shared.add));
    await tapAction(t, 'Canon A-1 (copy)', 'Share with lenses');
    expect(shared.single, isA<Kit>());
    expect((shared.single as Kit).lenses.map((l) => l.id), ['canon-fd-50-1.8']);
    await t.tap(find.byIcon(Icons.more_vert).first);
    await t.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('user body menu lists Edit and Delete', (t) async {
    await gear.saveUser(gear.duplicateBody(libBody('canon-a1')));
    await open(t, () => BodyPickerScreen(gear: gear));
    final row = find.ancestor(
      of: find.text('Canon A-1 (copy)'),
      matching: find.byType(InkWell),
    );
    await t.tap(
      find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert)),
    );
    await t.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('Lenses action only with a selected body', (t) async {
    await open(t, () => BodyPickerScreen(gear: gear));
    expect(find.text('Lenses'), findsNothing);
    await t.pageBack();
    await t.pumpAndSettle();
    await gear.selectBody(libBody('canon-a1'));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Lenses'));
    await t.pumpAndSettle();
    expect(find.text('No lens'), findsOneWidget);
  });
}
