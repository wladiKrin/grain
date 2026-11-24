import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/main.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/meter/meter_screen.dart';
import 'package:grain/rolls/latitude.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/haptics.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_source.dart';
import 'support/gear_fixtures.dart';
import 'support/rolls_fixtures.dart';

class _NoHaptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pumpAndSettle();
  }
}

void main() {
  late FakeMeterSource src;
  late GearController gear;
  late RollController rolls;
  final a1 = libBody('canon-a1');
  final ae1 = libBody('canon-ae1');

  setUp(() {
    src = FakeMeterSource(logRegions: false);
    gear = GearController.inMemory(library: fixtureLibrary());
    rolls = inMemoryRolls(takeSnapshot: src.snapshot);
  });
  tearDown(() {
    rolls.dispose();
    gear.dispose();
  });

  Future<void> pumpApp(
    WidgetTester t, {
    bool roll = true,
    FilmType filmType = FilmType.bwNeg,
    Settings? settings,
  }) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.runAsync(() async {
      await gear.selectBody(a1);
      if (roll) {
        await rolls.startRoll(
          filmStock: 'Ilford HP5 Plus',
          filmType: filmType,
          boxIso: 400,
          pushThirds: 0,
          body: a1,
          size: 36,
          startFrame: StartFrame.one,
        );
      }
    });
    await t.pumpWidget(
      GrainApp(
        source: src,
        haptics: _NoHaptics(),
        gear: gear,
        rolls: rolls,
        settings: settings,
      ),
    );
    await settle(t);
  }

  Future<void> pickBody(WidgetTester t, String name) async {
    await t.tap(find.byIcon(Icons.expand_more).first);
    await settle(t);
    await t.tap(find.text(name));
    await settle(t);
  }

  Future<void> back(WidgetTester t) async {
    await t.tap(find.byIcon(Icons.arrow_back).last);
    await settle(t);
  }

  MeterController meter(WidgetTester t) =>
      t.widget<MeterScreen>(find.byType(MeterScreen)).controller;

  const startAnother = 'Finish roll 1 and start a new one';

  testWidgets('choosing another body asks once the library closes', (t) async {
    await pumpApp(t);
    await t.tap(find.byIcon(Icons.expand_more).first);
    await settle(t);
    await t.tap(find.text('Canon AE-1'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    // Still in the library or just closed: the dialog waits for the route.
    await settle(t);
    expect(find.text('Library'), findsNothing);
    expect(find.text('Roll 1 is in the Canon A-1'), findsOneWidget);
    expect(find.text("Meter only (don't log)"), findsOneWidget);
    // Not dismissible by tapping outside.
    await t.tapAt(const Offset(5, 5));
    await settle(t);
    expect(find.text('Roll 1 is in the Canon A-1'), findsOneWidget);
    expect(gear.body, ae1);
  });

  testWidgets('the roll can move to another body of the same format', (
    t,
  ) async {
    await pumpApp(t);
    await pickBody(t, 'Canon AE-1');
    await t.tap(find.text('Move roll 1 to the Canon AE-1'));
    await settle(t);
    expect(rolls.active!.bodyId, 'canon-ae1');
    expect(rolls.active!.bodyName, 'Canon AE-1');
    expect(find.text('Log frame 1'), findsOneWidget);
  });

  testWidgets('no move to a body of another format', (t) async {
    await pumpApp(t);
    await pickBody(t, 'Pentax 67');
    expect(find.text('Roll 1 is in the Canon A-1'), findsOneWidget);
    expect(find.textContaining('Move roll'), findsNothing);
  });

  testWidgets('cycling the camera chip away from the roll asks too', (t) async {
    await t.runAsync(() async {
      await gear.toggleFavorite(a1);
      await gear.toggleFavorite(ae1);
    });
    await pumpApp(t);
    await t.tap(find.text('Canon A-1'));
    await settle(t);
    expect(gear.body, ae1);
    expect(find.text('Roll 1 is in the Canon A-1'), findsOneWidget);
  });

  testWidgets("meter only keeps the roll and saves readings", (t) async {
    await pumpApp(t);
    await pickBody(t, 'Canon AE-1');
    await t.tap(find.text("Meter only (don't log)"));
    await settle(t);
    expect(find.text('Save reading'), findsOneWidget);
    expect(find.text('Log frame 1'), findsNothing);
    expect(rolls.active!.number, 1);
    expect(rolls.active!.bodyId, 'canon-a1');
  });

  testWidgets(
    'finish and start: old roll finished only when the new one is saved',
    (t) async {
      await pumpApp(t);
      await pickBody(t, 'Canon AE-1');
      await t.tap(find.text(startAnother));
      await settle(t);
      expect(find.text('Canon AE-1'), findsWidgets);
      expect(find.text('Saving finishes Roll 1.'), findsOneWidget);
      await back(t);
      expect(rolls.active!.number, 1);
      expect(rolls.rolls, hasLength(1));
      // No dialog again: the body did not change this time.
      expect(find.text('Roll 1 is in the Canon A-1'), findsNothing);

      // Back on the meter (AE-1 selected, roll 1 in A-1): Start roll.
      await t.tap(find.text('Start roll'));
      await settle(t);
      await t.tap(find.text('Save'));
      await settle(t);
      expect(find.text('Film: enter a film stock.'), findsNothing);
      // The editor copied HP5 from roll 1, so Save succeeded.
      expect(rolls.rolls, hasLength(2));
      final r1 = rolls.rolls.firstWhere((r) => r.number == 1);
      expect(r1.status, RollStatus.finished);
      expect(rolls.active!.number, 2);
      expect(rolls.active!.bodyId, 'canon-ae1');
      expect(find.text('Log frame 1'), findsOneWidget);
    },
  );

  testWidgets('finish and start from the dialog opens the editor for the new '
      'body and a saved roll logs there', (t) async {
    await pumpApp(t);
    await pickBody(t, 'Canon AE-1');
    await t.tap(find.text(startAnother));
    await settle(t);
    await t.tap(find.text('Save'));
    await settle(t);
    expect(
      rolls.rolls.firstWhere((r) => r.number == 1).status,
      RollStatus.finished,
    );
    expect(rolls.active!.bodyId, 'canon-ae1');
    expect(find.text('Log frame 1'), findsOneWidget);
    expect(find.text('Roll 1 is in the Canon A-1'), findsNothing);
  });

  testWidgets('reselecting the same body asks nothing', (t) async {
    await pumpApp(t);
    await pickBody(t, 'Canon A-1');
    expect(find.text('Roll 1 is in the Canon A-1'), findsNothing);
    expect(find.text('Library'), findsNothing);
    expect(find.text('Log frame 1'), findsOneWidget);
  });

  testWidgets('Start roll opens the editor and the meter logs afterwards', (
    t,
  ) async {
    await pumpApp(t, roll: false);
    expect(find.text('Save reading'), findsOneWidget);
    await t.tap(find.text('Start roll'));
    await settle(t);
    expect(find.text('Canon A-1'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Mystery 400');
    await t.pump();
    await t.tap(find.text('Save'));
    await settle(t);
    expect(rolls.active!.filmStock, 'Mystery 400');
    expect(rolls.active!.bodyId, 'canon-a1');
    expect(find.text('Log frame 1'), findsOneWidget);
    await t.tap(find.text('Log frame 1'));
    await settle(t);
    expect(find.text('Log frame 2'), findsOneWidget);
  });

  testWidgets(
    'the logging roll sets the latitude, meter-only falls back to negative',
    (t) async {
      await pumpApp(t, filmType: FilmType.slide);
      expect(meter(t).latitude, FilmLatitude.slide);
      await pickBody(t, 'Canon AE-1');
      await t.tap(find.text("Meter only (don't log)"));
      await settle(t);
      expect(meter(t).latitude, FilmLatitude.negative);
      await pickBody(t, 'Canon A-1');
      expect(meter(t).latitude, FilmLatitude.slide);
    },
  );

  testWidgets('the frame orientation is remembered', (t) async {
    final settings = Settings.inMemory();
    await pumpApp(t, settings: settings);
    expect(meter(t).frameLandscape, isTrue);
    final handle = t.ensureSemantics();
    await t.tap(find.bySemanticsLabel('Turn frame upright'));
    await settle(t);
    expect(settings.frameLandscape, isFalse);
    await t.runAsync(() => settings.setFrameLandscape(true));
    await settle(t);
    expect(meter(t).frameLandscape, isTrue);
    handle.dispose();
  });

  testWidgets('the histogram choice is remembered', (t) async {
    final settings = Settings.inMemory();
    await pumpApp(t, settings: settings);
    expect(meter(t).histogramOn, isFalse);
    final handle = t.ensureSemantics();
    await t.tap(find.bySemanticsLabel('Show histogram'));
    await settle(t);
    expect(settings.histogram, isTrue);
    await t.runAsync(() => settings.setHistogram(false));
    await settle(t);
    expect(meter(t).histogramOn, isFalse);
    handle.dispose();
  });
}
