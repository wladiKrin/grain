import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/ui/frame_editor.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_location.dart';
import '../../support/gear_fixtures.dart';
import '../../support/rolls_fixtures.dart';
import '../../support/stops_finder.dart';

void main() {
  late RollController rolls;
  late Roll roll;
  late Frame frame;
  final a1 = libBody('canon-a1');
  final ae1 = libBody('canon-ae1');
  final fm2 = libBody('nikon-fm2');
  final fd28 = libLens('canon-fd-28-2.8');
  final fd50 = libLens('canon-fd-50-1.8');

  late Settings settings;

  setUp(() {
    settings = Settings.inMemory();
    rolls = inMemoryRolls(
      settings: settings,
      location: FakeLocation(
        const GeoFix(latitude: 52.52, longitude: 13.405, accuracy: 1500),
      ),
    );
  });
  tearDown(() => rolls.dispose());

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump();
  }

  Future<void> start(WidgetTester t, {bool located = false, Exposure? e}) =>
      t.runAsync(() async {
        if (located) await settings.setLocation(true);
        roll = await rolls.startRoll(
          filmStock: 'Ilford HP5 Plus',
          filmType: FilmType.bwNeg,
          boxIso: 400,
          pushThirds: 0,
          body: a1,
          size: 36,
          startFrame: StartFrame.one,
        );
        frame = await rolls.logFrame(
          e ??
              Exposure(
                mode: MeterMode.aperturePriority,
                aperture: 5.6,
                shutter: '1/125',
                exposureTime: 1 / 125,
                iso: 400,
                lensId: fd50.id,
                lensMake: fd50.make,
                lensName: fd50.name,
                focal: 50,
                meteredEv: 12.34,
                offset: 2 / 3,
                area: MeterArea.spot,
              ),
          note: 'old',
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        frame = (await rolls.framesOf(roll.id)).single;
      });

  Future<void> pumpEditor(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 3200);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute<void>(
                builder: (_) => FrameEditorScreen(
                  rolls: rolls,
                  roll: roll,
                  frame: frame,
                  bodies: [a1, ae1, fm2],
                  lensesFor: (m) => m == a1.mount ? [fd28, fd50] : const [],
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> enter(WidgetTester t, String label, String v) async {
    await t.ensureVisible(field(label));
    await t.enterText(field(label), v);
    await t.pump();
  }

  Future<void> save(WidgetTester t) async {
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    await settle(t);
  }

  Frame saved() => rolls.activeFrames.single;

  bool saveEnabled(WidgetTester t) =>
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Save')).onPressed !=
      null;

  testWidgets('edits aperture, shutter, ISO, lens, note', (t) async {
    await start(t);
    await pumpEditor(t);
    await enter(t, 'Aperture', '8');
    await enter(t, 'Shutter', '1/60');
    await enter(t, 'ISO', '400');
    await t.tap(find.text(fd50.name));
    await t.pumpAndSettle();
    await t.tap(find.text(fd28.name).last);
    await t.pumpAndSettle();
    await enter(t, 'Note', 'pier');
    await save(t);
    await t.pumpAndSettle();
    final e = saved().exposure;
    expect(e.aperture, 8);
    expect(e.shutter, '1/60');
    expect(e.exposureTime, closeTo(1 / 60, 1e-12));
    expect(e.iso, 400);
    expect(e.lensId, 'canon-fd-28-2.8');
    expect(e.lensName, fd28.name);
    expect(e.focal, 28);
    expect(saved().note, 'pier');
    // Measurements are untouched.
    expect(e.meteredEv, 12.34);
    expect(e.offset, 2 / 3);
    expect(e.area, MeterArea.spot);
    expect(find.byType(FrameEditorScreen), findsNothing);
  });

  testWidgets('shutter "2" is stored as 2"', (t) async {
    await start(t);
    await pumpEditor(t);
    await enter(t, 'Shutter', '2');
    await save(t);
    expect(saved().exposure.shutter, '2"');
    expect(saved().exposure.exposureTime, 2);
  });

  testWidgets('shutter B keeps the old time', (t) async {
    await start(t);
    await pumpEditor(t);
    await enter(t, 'Shutter', 'b');
    await save(t);
    expect(saved().exposure.shutter, 'B');
    expect(saved().exposure.exposureTime, closeTo(1 / 125, 1e-12));
  });

  testWidgets('refuses a bad shutter', (t) async {
    await start(t);
    await pumpEditor(t);
    await enter(t, 'Shutter', '1/0');
    expect(find.textContaining('Shutter:'), findsOneWidget);
    expect(saveEnabled(t), isFalse);
    await enter(t, 'Shutter', '1/60');
    expect(saveEnabled(t), isTrue);
    await enter(t, 'Aperture', '0.2');
    expect(saveEnabled(t), isFalse);
    await enter(t, 'Aperture', '5.6');
    await enter(t, 'ISO', '30000');
    expect(saveEnabled(t), isFalse);
  });

  testWidgets('remove location', (t) async {
    await start(t, located: true);
    expect(frame.location, isNotNull);
    await pumpEditor(t);
    expect(find.text('52.5200, 13.4050 ± 1500 m'), findsOneWidget);
    await t.ensureVisible(find.text('Remove location'));
    await t.tap(find.text('Remove location'));
    await t.pumpAndSettle();
    await settle(t);
    expect(find.text('Remove location'), findsNothing);
    expect(saved().location, isNull);
  });

  testWidgets('metered values are read-only', (t) async {
    await start(t);
    await pumpEditor(t);
    expect(findStops('Metered EV 12.3 · offset +⅔ · spot'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(5));
    expect(find.widgetWithText(TextField, 'Metered EV'), findsNothing);
  });

  testWidgets('a lens outside the mount list is kept', (t) async {
    await start(
      t,
      e: const Exposure(lensId: 'gone', lensName: 'Old 35mm f/2', focal: 35),
    );
    await pumpEditor(t);
    expect(find.text('Old 35mm f/2'), findsOneWidget);
    await save(t);
    expect(saved().exposure.lensId, 'gone');
    expect(saved().exposure.lensName, 'Old 35mm f/2');
  });

  testWidgets('the camera field defaults to the frame camera', (t) async {
    await start(t);
    expect(frame.bodyId, 'canon-a1');
    await pumpEditor(t);
    expect(
      find.descendant(
        of: find.byType(InputDecorator).first,
        matching: find.text('Canon A-1'),
      ),
      findsOneWidget,
    );
    expect(find.text('Camera'), findsOneWidget);
  });

  testWidgets('a frame moves to another camera of the format', (t) async {
    await start(t);
    await pumpEditor(t);
    await t.tap(find.text('Canon A-1').first);
    await t.pumpAndSettle();
    expect(find.text('Nikon FM2'), findsWidgets);
    await t.tap(find.text('Canon AE-1').last);
    await t.pumpAndSettle();
    await save(t);
    expect(saved().bodyId, 'canon-ae1');
    expect(saved().bodyName, 'Canon AE-1');
    // Same mount: the lens stays.
    expect(saved().exposure.lensId, fd50.id);
    // The roll stays in its camera.
    expect(rolls.active!.bodyId, 'canon-a1');
  });

  testWidgets('another mount keeps the frame lens as it was', (t) async {
    await start(t);
    await pumpEditor(t);
    await t.tap(find.text('Canon A-1').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Nikon FM2').last);
    await t.pumpAndSettle();
    expect(find.text(fd50.name), findsOneWidget);
    await save(t);
    expect(saved().bodyId, 'nikon-fm2');
    expect(saved().exposure.lensName, fd50.name);
  });

  testWidgets('a frame camera not offered is kept', (t) async {
    await start(t);
    await t.runAsync(
      () => rolls.updateFrame(
        frame.copyWith(bodyId: () => 'gone', bodyMake: 'Old', bodyModel: 'Box'),
      ),
    );
    frame = rolls.activeFrames.single;
    await pumpEditor(t);
    expect(find.text('Old Box'), findsOneWidget);
    await enter(t, 'Note', 'kept');
    await save(t);
    expect(saved().bodyId, 'gone');
    expect(saved().bodyName, 'Old Box');
  });
}
