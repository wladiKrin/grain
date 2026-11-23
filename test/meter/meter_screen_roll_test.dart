import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/main.dart';
import 'package:grain/meter/widgets/iso_stepper.dart';
import 'package:grain/meter/widgets/log_button.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/roll_repository.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/haptics.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_source.dart';
import '../support/gear_fixtures.dart';
import '../support/rolls_fixtures.dart';

class _Haptics implements Haptics {
  final ticks = <bool>[];
  @override
  void tick({required bool strong}) => ticks.add(strong);
}

void main() {
  late GearController gear;
  late FakeMeterSource src;
  late RollController rolls;
  late _Haptics haptics;
  final a1 = libBody('canon-a1');
  final ae1 = libBody('canon-ae1');

  setUp(() {
    gear = GearController.inMemory(library: fixtureLibrary());
    src = FakeMeterSource(logRegions: false);
    haptics = _Haptics();
    rolls = inMemoryRolls(takeSnapshot: src.snapshot);
  });
  tearDown(() {
    rolls.dispose();
    gear.dispose();
  });

  Future<void> pumpApp(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      GrainApp(source: src, haptics: haptics, gear: gear, rolls: rolls),
    );
    await t.pump();
  }

  /// A roll numbered [number] in [body], [push] thirds pushed.
  Future<void> startRoll(
    WidgetTester t,
    Body body, {
    int number = 4,
    int push = 3,
  }) => t.runAsync(() async {
    for (var i = 1; i <= number; i++) {
      await rolls.startRoll(
        filmStock: 'Ilford HP5 Plus',
        filmType: FilmType.bwNeg,
        boxIso: 400,
        pushThirds: i == number ? push : 0,
        body: body,
        size: 36,
        startFrame: StartFrame.one,
      );
    }
  });

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump();
  }

  testWidgets('no roll: Save reading with Start roll', (t) async {
    await pumpApp(t);
    expect(find.text('Save reading'), findsOneWidget);
    expect(find.text('Start roll'), findsOneWidget);
    await t.tap(find.text('Save reading'));
    await t.pump();
    expect(rolls.readings.length, 1);
    expect(rolls.readings.single.exposure.mode, isNotNull);
    expect(find.text('Reading saved'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(haptics.ticks, [true]);
    await settle(t);
    // Free mode: the reading is for no body, 35 mm.
    expect(rolls.readings.single.bodyId, isNull);
    expect(rolls.readings.single.format, FilmFormat.f135);
    // The snapshot is requested once; the fake answers null, so none attaches.
    expect(src.calls.where((c) => c.startsWith('snapshot(')), hasLength(1));
  });

  testWidgets('the Undo message goes away by itself', (t) async {
    await pumpApp(t);
    await t.tap(find.text('Save reading'));
    await t.pump();
    expect(find.text('Undo'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('undo of a saved reading removes it', (t) async {
    await pumpApp(t);
    await t.tap(find.text('Save reading'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(rolls.readings, isEmpty);
  });

  testWidgets('active roll: Log frame N counts up and the header shows the '
      'roll', (t) async {
    await t.runAsync(() => gear.selectBody(a1));
    await pumpApp(t);
    await startRoll(t, a1);
    await t.pump();
    expect(find.text('Log frame 1'), findsOneWidget);
    expect(find.text('Roll 4 · frame 1/36'), findsOneWidget);
    expect(find.text('HP5 · 400 → 800'), findsOneWidget);
    expect(find.text('Start roll'), findsNothing);
    // The roll's exposed-at ISO drives the meter.
    expect(find.text('800'), findsOneWidget);
    await t.tap(find.text('Log frame 1'));
    await t.pump();
    expect(find.text('Log frame 2'), findsOneWidget);
    expect(find.text('Roll 4 · frame 2/36'), findsOneWidget);
    expect(find.text('Frame 1 logged'), findsOneWidget);
    await settle(t);
    expect(src.calls.where((c) => c.startsWith('snapshot(')), hasLength(1));
    expect(rolls.activeFrames.single.exposure.iso, 800);
  });

  testWidgets('the button updates before the snapshot arrives', (t) async {
    await t.runAsync(() => gear.selectBody(a1));
    src.snapshotGate = Completer<void>();
    await pumpApp(t);
    await startRoll(t, a1);
    await t.pump();
    await t.tap(find.text('Log frame 1'));
    await t.pump();
    expect(find.text('Log frame 2'), findsOneWidget);
    expect(src.snapshotGate!.isCompleted, isFalse);
    src.snapshotGate!.complete();
    await settle(t);
  });

  testWidgets('undo removes the frame', (t) async {
    await t.runAsync(() => gear.selectBody(a1));
    await pumpApp(t);
    await startRoll(t, a1);
    await t.pump();
    await t.tap(find.text('Log frame 1'));
    await t.pump();
    expect(find.text('Log frame 2'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(find.text('Log frame 1'), findsOneWidget);
    expect(rolls.activeFrames, isEmpty);
  });

  testWidgets('the snack bar does not cover the button', (t) async {
    await t.runAsync(() => gear.selectBody(a1));
    await pumpApp(t);
    await startRoll(t, a1);
    await t.pump();
    await t.tap(find.text('Log frame 1'));
    await t.pump(const Duration(milliseconds: 400));
    final bar = t.getRect(find.text('Frame 1 logged'));
    final button = t.getRect(find.byType(LogButton));
    expect(bar.bottom, lessThanOrEqualTo(button.top));
    // So the next frame can be logged while it is still up.
    await t.tap(find.text('Log frame 2'));
    await t.pump();
    expect(find.text('Log frame 3'), findsOneWidget);
    await settle(t);
  });

  testWidgets('another body selected: meter only, Save reading', (t) async {
    await t.runAsync(() => gear.selectBody(a1));
    await pumpApp(t);
    await startRoll(t, a1);
    await t.runAsync(() => gear.selectBody(ae1));
    await t.pump();
    expect(find.text('Save reading'), findsOneWidget);
    expect(find.text('Start roll'), findsOneWidget);
    expect(
      find.text('Meter only · roll 4 is in the Canon A-1'),
      findsOneWidget,
    );
    expect(find.text('HP5 · 400 → 800'), findsNothing);
    await t.tap(find.text('Save reading'));
    await t.pump();
    expect(rolls.readings.single.bodyId, ae1.id);
    expect(rolls.activeFrames, isEmpty);
    await t.runAsync(() => gear.selectBody(a1));
    await t.pump();
    expect(find.text('Log frame 1'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
    await settle(t);
  });

  testWidgets('ISO marker shows when the ISO differs from the roll', (t) async {
    await t.runAsync(() => gear.selectBody(a1));
    await pumpApp(t);
    await startRoll(t, a1);
    await t.pump();
    IsoStepper stepper() => t.widget<IsoStepper>(find.byType(IsoStepper));
    expect(stepper().marked, isFalse);
    expect(find.bySemanticsLabel('ISO 800'), findsOneWidget);
    await t.tap(find.byIcon(Icons.add));
    await t.pump();
    expect(stepper().marked, isTrue);
    expect(find.text('1000'), findsOneWidget);
    expect(
      find.bySemanticsLabel('ISO 1000, differs from the roll'),
      findsOneWidget,
    );
    await t.tap(find.byIcon(Icons.remove));
    await t.pump();
    expect(stepper().marked, isFalse);
  });

  testWidgets('a new roll starts at its own ISO', (t) async {
    await t.runAsync(() => gear.selectBody(a1));
    await pumpApp(t);
    await startRoll(t, a1, number: 1, push: 0);
    await t.pump();
    await t.tap(find.byIcon(Icons.add));
    await t.pump();
    expect(find.text('500'), findsOneWidget);
    await t.runAsync(
      () => rolls.startRoll(
        filmStock: 'Ilford HP5 Plus',
        filmType: FilmType.bwNeg,
        boxIso: 400,
        pushThirds: 0,
        body: a1,
        size: 36,
        startFrame: StartFrame.one,
      ),
    );
    await t.pump();
    expect(find.text('400'), findsOneWidget);
    expect(find.text('Roll 2 · frame 1/36'), findsOneWidget);
  });

  testWidgets('a roll past its size shows +k', (t) async {
    await t.runAsync(() => gear.selectBody(a1));
    await pumpApp(t);
    await t.runAsync(
      () => rolls.startRoll(
        filmStock: 'Ilford HP5 Plus',
        filmType: FilmType.bwNeg,
        boxIso: 400,
        pushThirds: 0,
        body: a1,
        size: 1,
        startFrame: StartFrame.one,
      ),
    );
    await t.pump();
    await t.tap(find.text('Log frame 1'));
    await t.pump();
    expect(find.text('Roll 1 · frame 2/1 +1'), findsOneWidget);
    await settle(t);
  });

  group('a write that fails', () {
    late RollController failing;
    late _FailingRepository repo;

    setUp(() {
      repo = _FailingRepository();
      failing = RollController(
        repository: repo,
        snapshots: rolls.snapshots,
        settings: Settings.inMemory(),
      );
    });
    tearDown(() => failing.dispose());

    Future<void> pumpFailing(WidgetTester t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpWidget(
        GrainApp(source: src, haptics: haptics, gear: gear, rolls: failing),
      );
      await t.pump();
    }

    testWidgets('reading: Not saved, no uncaught error', (t) async {
      await pumpFailing(t);
      await t.tap(find.text('Save reading'));
      await settle(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Not saved'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('reading: Undo while the write is pending, then it fails', (
      t,
    ) async {
      await pumpFailing(t);
      repo.gate = Completer<void>();
      await t.tap(find.text('Save reading'));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Undo'));
      repo.gate!.complete();
      await settle(t);
      await t.pump(const Duration(milliseconds: 400));
      // Nothing to undo, no error escapes, the failure is still reported.
      expect(find.text('Not saved'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('frame: Not saved, no uncaught error', (t) async {
      await t.runAsync(() => gear.selectBody(a1));
      await pumpFailing(t);
      await t.runAsync(
        () => failing.startRoll(
          filmStock: 'Ilford HP5 Plus',
          filmType: FilmType.bwNeg,
          boxIso: 400,
          pushThirds: 0,
          body: a1,
          size: 36,
          startFrame: StartFrame.one,
        ),
      );
      await t.pump();
      await t.tap(find.text('Log frame 1'));
      await settle(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Not saved'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}

/// Fails the writes the meter makes while logging.
class _FailingRepository extends MemoryRollRepository {
  /// When set, a reading write waits for it before failing.
  Completer<void>? gate;

  @override
  Future<void> saveReading(SavedReading r) async {
    await gate?.future;
    throw StateError('disk full');
  }

  @override
  Future<void> saveFrames(List<Frame> frames) async =>
      throw StateError('disk full');
}
