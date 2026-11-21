import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/gear/ui/body_editor.dart';
import 'package:grain/gear/ui/lens_editor.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/gear_fixtures.dart';

late GearController gear;
Object? popped;

Future<void> open(WidgetTester t, Widget Function() screen) async {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  popped = null;
  await t.pumpWidget(
    MaterialApp(
      theme: grainTheme(),
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () async => popped = await Navigator.push<Object>(
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

Finder field(String label) => find.widgetWithText(TextField, label);

void main() {
  setUp(() => gear = GearController.inMemory(library: fixtureLibrary()));

  testWidgets('editor refuses a body without a timed speed', (t) async {
    final copy = gear.duplicateBody(libBody('canon-a1'));
    await open(
      t,
      () => BodyEditorScreen(gear: gear, initial: copy, isNew: true),
    );
    for (final m in copy.shutter) {
      if (m == 'B') continue;
      await t.tap(find.widgetWithText(FilterChip, m));
    }
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(
      find.text('shutter: needs at least one timed speed'),
      findsOneWidget,
    );
    expect(gear.bodies.any((b) => b.id == 'canon-a-1-copy'), isFalse);
    expect(popped, isNull);
    expect(find.text('New body'), findsOneWidget);
  });

  testWidgets('new body: empty make is refused, then a filled one saves', (
    t,
  ) async {
    await open(
      t,
      () =>
          BodyEditorScreen(gear: gear, initial: newBodyTemplate(), isNew: true),
    );
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.textContaining('id:'), findsOneWidget);
    expect(gear.bodies.length, fixtureLibrary().bodies.length);

    await t.enterText(field('Make'), 'Zenit');
    await t.enterText(field('Model'), 'E');
    await t.enterText(field('Mount'), 'm42');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final saved = popped as Body;
    expect(saved.id, 'zenit-e');
    expect(saved.mount, 'm42');
    expect(saved.format, FilmFormat.f135);
    expect(saved.shutter.last, 'B');
    expect(gear.isUser(saved), isTrue);
  });

  testWidgets('format change refills frames only from the old default', (
    t,
  ) async {
    await open(
      t,
      () =>
          BodyEditorScreen(gear: gear, initial: newBodyTemplate(), isNew: true),
    );
    Future<void> pick(String label) async {
      await t.tap(find.byType(DropdownButton<FilmFormat>));
      await t.pumpAndSettle();
      await t.tap(find.text(label).last);
      await t.pumpAndSettle();
    }

    String frames() => t.widget<TextField>(field('Frames')).controller!.text;
    await pick('6×6');
    expect(frames(), '12');
    await t.enterText(field('Frames'), '20');
    await pick('6×9');
    expect(frames(), '20');
  });

  testWidgets('editing a user body keeps its id', (t) async {
    final user = await gear.saveUser(gear.duplicateBody(libBody('canon-a1')));
    await open(
      t,
      () => BodyEditorScreen(gear: gear, initial: user, isNew: false),
    );
    expect(find.text('Edit body'), findsOneWidget);
    await t.enterText(field('Model'), 'Renamed');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect((popped as Body).id, user.id);
    expect(gear.bodies.where((b) => b.id == user.id).single.model, 'Renamed');
  });

  testWidgets('non-standard shutter marks of the initial body get a chip', (
    t,
  ) async {
    final b = newBodyTemplate().copyWith(
      make: 'X',
      model: 'Y',
      mount: 'x',
      shutter: ['1/1000', '1/350', 'B'],
    );
    await open(t, () => BodyEditorScreen(gear: gear, initial: b, isNew: true));
    expect(find.widgetWithText(FilterChip, '1/350'), findsOneWidget);
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect((popped as Body).shutter, ['1/1000', '1/350', 'B']);
  });

  testWidgets('lens editor builds a varying-aperture zoom', (t) async {
    await open(
      t,
      () => LensEditorScreen(
        gear: gear,
        initial: newLensTemplate('canon-fd'),
        isNew: true,
        mount: 'canon-fd',
      ),
    );
    await t.enterText(field('Make'), 'Canon');
    await t.enterText(field('Name'), 'Test 28-85mm');
    await t.tap(find.text('Zoom'));
    await t.pumpAndSettle();
    await t.enterText(field('Focal length from (mm)'), '28');
    await t.enterText(field('Focal length to (mm)'), '85');
    await t.enterText(field('Widest aperture at wide end (f/)'), '3.5');
    await t.enterText(field('Widest aperture at long end (f/)'), '4.5');
    await t.enterText(field('Smallest aperture (f/)'), '22');
    await t.tap(find.text('Half'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final l = popped as Lens;
    expect(l.id, 'canon-test-28-85mm');
    expect(l.mount, 'canon-fd');
    expect(l.focalMin, 28);
    expect(l.focalMax, 85);
    expect(l.maxAperture, [ApertureAt(28, 3.5), ApertureAt(85, 4.5)]);
    expect(l.minAperture, 22);
    expect(l.apertureStep, StepSize.half);
    expect(gear.isUser(l), isTrue);
    expect(gear.lensesFor('canon-fd'), hasLength(6));
  });

  testWidgets('lens editor shows the first validation error', (t) async {
    await open(
      t,
      () => LensEditorScreen(
        gear: gear,
        initial: newLensTemplate('canon-fd'),
        isNew: true,
      ),
    );
    await t.enterText(field('Make'), 'Canon');
    await t.enterText(field('Name'), 'Bad');
    await t.enterText(field('Smallest aperture (f/)'), '1');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(
      find.text('minAperture: must be greater than every maxAperture'),
      findsOneWidget,
    );
    expect(popped, isNull);
    await t.enterText(field('Smallest aperture (f/)'), '');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('minAperture: must be a number'), findsOneWidget);
  });
}
