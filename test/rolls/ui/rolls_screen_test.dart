import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/main.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/ui/rolls_screen.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_location.dart';
import '../../support/fake_source.dart';
import '../../support/gear_fixtures.dart';
import '../../support/rolls_fixtures.dart';

class _Haptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

void main() {
  late RollController rolls;
  late GearController gear;
  final a1 = libBody('canon-a1');

  setUp(() {
    gear = GearController.inMemory(library: fixtureLibrary());
    rolls = inMemoryRolls();
  });
  tearDown(() {
    rolls.dispose();
    gear.dispose();
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 3; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pumpAndSettle();
    }
  }

  void bigView(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
  }

  Future<Roll> roll(
    WidgetTester t,
    String stock, {
    int push = 0,
    int frames = 0,
    bool finish = false,
  }) => t
      .runAsync(() async {
        final r = await rolls.startRoll(
          filmStock: stock,
          filmType: FilmType.bwNeg,
          boxIso: 400,
          pushThirds: push,
          body: a1,
          size: 36,
          startFrame: StartFrame.one,
        );
        for (var i = 0; i < frames; i++) {
          await rolls.logFrame(
            Exposure(aperture: 5.6, shutter: '1/125', iso: 400),
          );
        }
        if (finish) await rolls.finishRoll(r.id);
        await Future<void>.delayed(Duration.zero);
        return r;
      })
      .then((r) => r!);

  Future<void> reading(WidgetTester t, {double ap = 5.6, String? note}) =>
      t.runAsync(() async {
        await rolls.saveReading(
          Exposure(
            aperture: ap,
            shutter: '1/125',
            iso: 400,
            lensName: 'FD 50mm f/1.8',
          ),
          body: a1,
          format: a1.format,
          note: note,
        );
        await Future<void>.delayed(Duration.zero);
      });

  Future<void> pumpScreen(
    WidgetTester t, {
    void Function({String? rollId})? onOpenMap,
  }) async {
    bigView(t);
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: RollsScreen(
          rolls: rolls,
          gear: gear,
          haptics: _Haptics(),
          onOpenMap: onOpenMap,
        ),
      ),
    );
    await settle(t);
  }

  Finder inTabs(String text) =>
      find.descendant(of: find.byType(TabBar), matching: find.text(text));

  testWidgets('active roll first, then finished newest first', (t) async {
    await roll(t, 'Kodak Gold', finish: true);
    await roll(t, 'Ilford HP5 Plus', finish: true);
    await roll(t, 'Portra 400');
    await pumpScreen(t);
    final y3 = t.getTopLeft(find.text('Roll 3 · Portra 400')).dy;
    final y2 = t.getTopLeft(find.text('Roll 2 · Ilford HP5 Plus')).dy;
    final y1 = t.getTopLeft(find.text('Roll 1 · Kodak Gold')).dy;
    expect(y3, lessThan(y2));
    expect(y2, lessThan(y1));
    expect(find.text('Active'), findsOneWidget);
    // On the same row as roll 3.
    expect(t.getCenter(find.text('Active')).dy, closeTo(y3 + 10, 40));
  });

  testWidgets('roll row shows push and frame count, also when finished', (
    t,
  ) async {
    await roll(t, 'Ilford HP5 Plus', push: 3, frames: 12);
    await roll(t, 'Kodak Gold', frames: 5, finish: true);
    await pumpScreen(t);
    expect(find.text('Push +1 · Canon A-1 · 12/36'), findsOneWidget);
    // The older, finished roll is listed second.
    expect(find.text('Canon A-1 · 5/36'), findsOneWidget);
    expect(find.textContaining('—/'), findsNothing);
  });

  testWidgets('a roll shot in two cameras lists both', (t) async {
    final r = await roll(t, 'Ilford HP5 Plus', frames: 1);
    await t.runAsync(() async {
      await rolls.continueRoll(r.id, libBody('nikon-fm2'));
      await rolls.logFrame(const Exposure(aperture: 8));
    });
    await pumpScreen(t);
    expect(find.text('Canon A-1 → Nikon FM2 · 2/36'), findsOneWidget);
  });

  testWidgets('tapping a roll opens the roll view', (t) async {
    await roll(t, 'Ilford HP5 Plus', frames: 2);
    await pumpScreen(t);
    await t.tap(find.text('Roll 1 · Ilford HP5 Plus'));
    await settle(t);
    expect(find.text('Roll 1'), findsOneWidget); // app bar of RollScreen
    expect(find.text('Box speed · ISO 400'), findsOneWidget);
  });

  testWidgets('the Map button opens the map of every roll, and a roll '
      'passes it on to its own map', (t) async {
    await roll(t, 'Ilford HP5 Plus', frames: 1);
    await pumpScreen(t);
    expect(find.byTooltip('Map'), findsNothing);
    final opened = <String?>[];
    await pumpScreen(t, onOpenMap: ({rollId}) => opened.add(rollId));
    await t.tap(find.byTooltip('Map'));
    await settle(t);
    expect(opened, [null]);
    await t.tap(find.text('Roll 1 · Ilford HP5 Plus'));
    await settle(t);
    await t.tap(find.byTooltip('Map of this roll'));
    await settle(t);
    expect(opened, [null, rolls.rolls.single.id]);
  });

  testWidgets('the + button opens the roll editor', (t) async {
    await pumpScreen(t);
    await t.tap(find.byTooltip('New roll'));
    await settle(t);
    expect(find.text('Start roll'), findsWidgets);
  });

  testWidgets('saved readings list and delete', (t) async {
    await reading(t, ap: 5.6);
    await reading(t, ap: 8);
    await pumpScreen(t);
    await t.tap(inTabs('Saved readings'));
    await settle(t);
    expect(find.text('f/5.6 · 1/125 · ISO 400'), findsOneWidget);
    expect(find.text('f/8 · 1/125 · ISO 400'), findsOneWidget);
    expect(find.text('Canon A-1 · FD 50/1.8'), findsNWidgets(2));
    await t.tap(find.text('f/8 · 1/125 · ISO 400'));
    await settle(t);
    await t.tap(find.widgetWithText(TextButton, 'Delete reading'));
    await settle(t);
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await settle(t);
    expect(rolls.readings, hasLength(1));
    expect(find.text('f/8 · 1/125 · ISO 400'), findsNothing);
    expect(find.text('f/5.6 · 1/125 · ISO 400'), findsOneWidget);
  });

  testWidgets('reading note is saved on leave', (t) async {
    await reading(t, note: 'old');
    await pumpScreen(t);
    await t.tap(inTabs('Saved readings'));
    await settle(t);
    await t.tap(find.text('f/5.6 · 1/125 · ISO 400'));
    await settle(t);
    await t.enterText(find.byType(TextField), 'backlit window');
    await t.tap(find.byIcon(Icons.arrow_back));
    await settle(t);
    expect(rolls.readings.single.note, 'backlit window');
  });

  testWidgets('a note typed is saved when the app is backgrounded and '
      'later edits save too', (t) async {
    await reading(t, note: 'old');
    await pumpScreen(t);
    await t.tap(inTabs('Saved readings'));
    await settle(t);
    await t.tap(find.text('f/5.6 · 1/125 · ISO 400'));
    await settle(t);
    await t.enterText(find.byType(TextField), 'first');
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    expect(rolls.readings.single.note, 'first');
    await t.enterText(find.byType(TextField), 'second');
    await t.pump(const Duration(milliseconds: 900));
    expect(rolls.readings.single.note, 'second');
    await t.enterText(find.byType(TextField), 'third');
    await t.tap(find.byIcon(Icons.arrow_back));
    await settle(t);
    expect(rolls.readings.single.note, 'third');
  });

  testWidgets('a reading can drop its location and its snapshot', (t) async {
    rolls.dispose();
    final settings = Settings.inMemory();
    late RollController r2;
    r2 = rolls = inMemoryRolls(
      settings: settings,
      location: FakeLocation(
        const GeoFix(latitude: 52.52, longitude: 13.405, accuracy: 1500),
      ),
      takeSnapshot: (id) async {
        final f = File('${r2.snapshots.dir.path}/$id.jpg');
        await f.writeAsBytes([1, 2, 3]);
        return f.path;
      },
    );
    await t.runAsync(() => settings.setLocation(true));
    await reading(t);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(rolls.readings.single.location, isNotNull);
    expect(rolls.readings.single.snapshot, isNotNull);
    await pumpScreen(t);
    await t.tap(inTabs('Saved readings'));
    await settle(t);
    await t.tap(find.text('f/5.6 · 1/125 · ISO 400'));
    await settle(t);
    expect(find.textContaining('52.5200, 13.4050'), findsOneWidget);
    await t.ensureVisible(find.text('Remove location'));
    await t.tap(find.text('Remove location'));
    await settle(t);
    expect(rolls.readings.single.location, isNull);
    expect(find.text('Remove location'), findsNothing);
    final name = rolls.readings.single.snapshot!;
    await t.ensureVisible(find.text('Delete snapshot'));
    await t.tap(find.text('Delete snapshot'));
    await settle(t);
    expect(rolls.readings.single.snapshot, isNull);
    expect(rolls.snapshots.file(name).existsSync(), isFalse);
    expect(find.text('Delete snapshot'), findsNothing);
  });

  testWidgets('empty states', (t) async {
    await pumpScreen(t);
    expect(
      find.text('No rolls yet. Start one from the meter or with +.'),
      findsOneWidget,
    );
    await t.tap(inTabs('Saved readings'));
    await settle(t);
    expect(
      find.text(
        "No saved readings. With no roll loaded, the meter's button saves "
        'one.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the meter rolls button opens Rolls and releases the camera', (
    t,
  ) async {
    final src = FakeMeterSource(logRegions: false);
    bigView(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.runAsync(() => gear.selectBody(a1));
    await t.pumpWidget(GrainApp(source: src, haptics: _Haptics(), gear: gear));
    await settle(t);
    await t.tap(find.bySemanticsLabel('Rolls and saved readings'));
    await settle(t);
    expect(find.byType(RollsScreen), findsOneWidget);
    expect(inTabs('Rolls'), findsOneWidget);
    expect(src.calls.last, 'stop');
  });
}
