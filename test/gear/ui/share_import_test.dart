import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/codec.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/gear/ui/body_picker.dart';
import 'package:grain/gear/ui/import_flow.dart';
import 'package:grain/gear/ui/share_sheet.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/fake_platform.dart';
import '../../support/gear_fixtures.dart';

late GearController gear;
late FakeGearPlatform platform;
ImportResult? lastResult;

Future<void> host(WidgetTester t, Widget Function(BuildContext) button) async {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: grainTheme(),
      home: Scaffold(body: Builder(builder: button)),
    ),
  );
}

Future<void> openShare(WidgetTester t, GearDoc doc) async {
  await host(
    t,
    (c) => TextButton(
      onPressed: () => showShareSheet(c, doc: doc, platform: platform),
      child: const Text('go'),
    ),
  );
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
}

Future<void> runImport(WidgetTester t) async {
  lastResult = null;
  await host(
    t,
    (c) => TextButton(
      onPressed: () async =>
          lastResult = await importFromFile(c, gear: gear, platform: platform),
      child: const Text('go'),
    ),
  );
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
}

void main() {
  final a1 = libBody('canon-a1');

  setUp(() {
    gear = GearController.inMemory(library: fixtureLibrary());
    platform = FakeGearPlatform();
  });

  testWidgets('share sheet shows a QR and shares the pretty file', (t) async {
    await openShare(t, a1);
    expect(find.text('Canon A-1'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    await t.tap(find.text('Share file'));
    await t.pumpAndSettle();
    expect(platform.shared, [('canon-a1.json', encodePretty(a1))]);
  });

  testWidgets('kit sheet shares body and favorite lenses', (t) async {
    await gear.toggleFavorite(libLens('canon-fd-28-2.8'));
    await gear.toggleFavorite(libLens('canon-fd-50-1.8'));
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: Builder(
          builder: (c) => BodyPickerScreen(
            gear: gear,
            onShare: (d) => showShareSheet(c, doc: d, platform: platform),
          ),
        ),
      ),
    );
    final row = find.ancestor(
      of: find.text('Canon A-1').first,
      matching: find.byType(InkWell),
    );
    await t.tap(
      find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert)),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Share with lenses'));
    await t.pumpAndSettle();
    expect(find.text('Canon A-1 + 2 lenses'), findsOneWidget);
    await t.tap(find.text('Share file'));
    await t.pumpAndSettle();
    final (name, text) = platform.shared.single;
    expect(name, 'canon-a1-kit.json');
    final kit = parseGearString(text) as Kit;
    expect(kit.body.id, 'canon-a1');
    expect(kit.lenses.map((l) => l.id), {'canon-fd-28-2.8', 'canon-fd-50-1.8'});
  });

  test(
    'kitFor adds the current lens once and offers no kit without lenses',
    () async {
      expect(kitFor(gear, a1).lenses, isEmpty);
      await gear.selectBody(a1);
      final fd50 = libLens('canon-fd-50-1.8');
      await gear.selectLens(fd50);
      expect(kitFor(gear, a1).lenses.map((l) => l.id), ['canon-fd-50-1.8']);
      await gear.toggleFavorite(fd50);
      expect(kitFor(gear, a1).lenses.map((l) => l.id), ['canon-fd-50-1.8']);
    },
  );

  testWidgets('oversized kit offers only the file', (t) async {
    await gear.selectBody(a1);
    for (var i = 0; i < 20; i++) {
      final l = await gear.saveUser(
        gear
            .duplicateLens(libLens('canon-fd-50-1.8'))
            .copyWith(name: 'Lens number $i ${'x' * 40}'),
      );
      await gear.toggleFavorite(l);
    }
    final kit = kitFor(gear, a1);
    expect(kit.lenses.length, greaterThanOrEqualTo(20));
    await openShare(t, kit);
    expect(
      find.text('Too large for one QR code — share it as a file.'),
      findsOneWidget,
    );
    expect(find.byType(QrImageView), findsNothing);
    await t.tap(find.text('Share file'));
    await t.pumpAndSettle();
    expect(platform.shared.single.$1, 'canon-a1-kit.json');
  });

  testWidgets('exported file re-imports without duplicates', (t) async {
    await openShare(t, a1);
    await t.tap(find.text('Share file'));
    platform.picked = platform.shared.single.$2;
    await t.tapAt(const Offset(10, 10)); // dismiss the sheet
    await t.pumpAndSettle();
    final before = gear.bodies.length;
    expect(gear.isFavorite(a1), isFalse);
    await runImport(t);
    expect(find.text('Import Canon A-1?'), findsOneWidget);
    await t.tap(find.text('Import'));
    await t.pumpAndSettle();
    expect(gear.bodies, hasLength(before));
    expect(gear.isFavorite(a1), isTrue);
    expect(find.text('Imported Canon A-1'), findsOneWidget);
    expect(lastResult!.bodies.single.id, 'canon-a1');
  });

  testWidgets('importing a modified copy keeps both', (t) async {
    platform.picked = encodePretty(a1.copyWith(model: 'A-1 mine'));
    final before = gear.bodies.length;
    await runImport(t);
    await t.tap(find.text('Import'));
    await t.pumpAndSettle();
    expect(gear.bodies, hasLength(before + 1));
    expect(
      gear.bodies.map((b) => b.id),
      containsAll(['canon-a1', 'canon-a1-2']),
    );
    expect(find.text('Imported Canon A-1 mine'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation imports nothing', (t) async {
    platform.picked = encodePretty(a1.copyWith(model: 'A-1 mine'));
    final before = gear.bodies.length;
    await runImport(t);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(gear.bodies, hasLength(before));
    expect(lastResult, isNull);
  });

  testWidgets('a kit asks about body and lenses', (t) async {
    platform.picked = encodePretty(
      Kit(a1.copyWith(model: 'A-1 mine'), [libLens('canon-fd-50-1.8')]),
    );
    await runImport(t);
    expect(find.text('Import Canon A-1 mine and 1 lens?'), findsOneWidget);
  });

  testWidgets('a cancelled pick does nothing', (t) async {
    await runImport(t);
    expect(find.byType(AlertDialog), findsNothing);
    expect(lastResult, isNull);
  });

  Future<void> refused(WidgetTester t, String text, String message) async {
    platform.picked = text;
    final bodies = gear.bodies.length;
    final lenses = gear.lensesFor('canon-fd').length;
    await runImport(t);
    expect(find.text('Not a Grain profile'), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.text('Import'), findsNothing);
    expect(gear.bodies, hasLength(bodies));
    expect(gear.lensesFor('canon-fd'), hasLength(lenses));
    expect(lastResult, isNull);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
  }

  testWidgets('non-Grain text is refused', (t) async {
    await refused(t, 'hello', '(root): not valid JSON');
  });

  testWidgets('random JSON is refused', (t) async {
    await refused(t, '{"a": 1}', 'schema: must be the integer 1');
    await refused(t, '[1, 2]', '(root): must be a JSON object');
  });

  testWidgets('a newer schema is refused with the upgrade message', (t) async {
    final m = jsonDecode(encodePretty(a1)) as Map<String, Object?>;
    m['schema'] = 2;
    await refused(
      t,
      jsonEncode(m),
      'schema: made by a newer version of Grain (schema 2)',
    );
  });

  testWidgets('an oversized file is refused', (t) async {
    platform.pickError = GearFormatException(['file: larger than 256 KB']);
    await runImport(t);
    expect(find.text('Not a Grain profile'), findsOneWidget);
    expect(find.text('file: larger than 256 KB'), findsOneWidget);
  });
}
