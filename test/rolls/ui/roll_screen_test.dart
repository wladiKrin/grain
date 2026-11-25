import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/ui/roll_screen.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/gear_fixtures.dart';
import '../../support/rolls_fixtures.dart';

class _Haptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

void main() {
  late RollController rolls;
  late GearController gear;
  late Roll roll;
  var snap = _Snap.none;
  final a1 = libBody('canon-a1');

  setUp(() {
    gear = GearController.inMemory(library: fixtureLibrary());
    snap = _Snap.none;
    rolls = inMemoryRolls(
      takeSnapshot: (id) async {
        if (snap == _Snap.none) return null;
        final f = File('${_dirOf(rolls)}/$id.jpg');
        if (snap == _Snap.written) await f.writeAsBytes([1, 2, 3]);
        return f.path;
      },
    );
  });
  tearDown(() {
    rolls.dispose();
    gear.dispose();
  });

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump();
  }

  /// Starts a roll and logs [n] frames (frame exposures given by [exposures]).
  Future<void> start(
    WidgetTester t, {
    int size = 36,
    int pushThirds = 0,
    int boxIso = 400,
    int n = 3,
    Exposure Function(int i)? exposure,
  }) => t.runAsync(() async {
    roll = await rolls.startRoll(
      filmStock: 'Ilford HP5 Plus',
      filmType: FilmType.bwNeg,
      boxIso: boxIso,
      pushThirds: pushThirds,
      body: a1,
      size: size,
      startFrame: StartFrame.one,
    );
    for (var i = 0; i < n; i++) {
      await rolls.logFrame(
        exposure?.call(i) ??
            Exposure(aperture: 5.6, shutter: '1/125', iso: roll.exposedIso),
      );
    }
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> pumpScreen(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: RollScreen(
          rolls: rolls,
          gear: gear,
          haptics: _Haptics(),
          rollId: roll.id,
          onExport: (_) {},
        ),
      ),
    );
    await settle(t);
  }

  Future<void> rowMenu(WidgetTester t, String label, String item) async {
    await t.tap(find.byTooltip('Frame $label actions'));
    await t.pumpAndSettle();
    await t.tap(find.text(item));
    await t.pumpAndSettle();
    await settle(t);
  }

  Future<void> rollMenu(WidgetTester t, String item) async {
    await t.tap(find.byTooltip('Roll actions'));
    await t.pumpAndSettle();
    await t.tap(find.text(item));
    await t.pumpAndSettle();
  }

  List<String> labels(WidgetTester t) => [
    for (final f in rolls.activeFrames) f.label,
  ];

  testWidgets('push is prominent and frames list in order', (t) async {
    await start(t, pushThirds: 3);
    await pumpScreen(t);
    expect(find.text('Push +1 · exposed at ISO 800'), findsOneWidget);
    expect(find.text('Ilford HP5 Plus'), findsOneWidget);
    final y1 = t.getTopLeft(find.text('1')).dy;
    final y2 = t.getTopLeft(find.text('2')).dy;
    final y3 = t.getTopLeft(find.text('3')).dy;
    expect(y1, lessThan(y2));
    expect(y2, lessThan(y3));
    expect(find.text('f/5.6 · 1/125'), findsNWidgets(3));
  });

  testWidgets('a single-camera roll names no camera on its frames', (t) async {
    await start(t);
    await pumpScreen(t);
    expect(find.text('Canon A-1 · 36 frames · first frame 1'), findsOneWidget);
    expect(find.textContaining('Canon A-1 ·'), findsOneWidget);
  });

  testWidgets('a multi-camera roll names each frame camera', (t) async {
    await start(t, n: 1);
    await t.runAsync(() async {
      await rolls.continueRoll(roll.id, libBody('nikon-fm2'));
      await rolls.logFrame(const Exposure(aperture: 8));
    });
    await pumpScreen(t);
    expect(
      find.text('Canon A-1 → Nikon FM2 · 36 frames · first frame 1'),
      findsOneWidget,
    );
    expect(find.textContaining(RegExp(r'^Canon A-1 · \d')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Nikon FM2 · \d')), findsOneWidget);
  });

  testWidgets('a blank inserted after a frame takes its camera', (t) async {
    await start(t, n: 1);
    await t.runAsync(() async {
      await rolls.continueRoll(roll.id, libBody('canon-ae1'));
      await rolls.logFrame(const Exposure(aperture: 8));
    });
    await pumpScreen(t);
    await rowMenu(t, '1', 'Insert blank after');
    expect(
      [for (final f in rolls.activeFrames) f.bodyId],
      ['canon-a1', 'canon-a1', 'canon-ae1'],
    );
    expect(find.text('Canon A-1'), findsOneWidget);
  });

  testWidgets('Edit roll corrects the camera of the frames on it', (t) async {
    await start(t, n: 2);
    final second = rolls.activeFrames[1];
    await t.runAsync(
      () => rolls.updateFrame(
        second.copyWith(
          bodyId: () => 'canon-ae1',
          bodyMake: 'Canon',
          bodyModel: 'AE-1',
        ),
      ),
    );
    await pumpScreen(t);
    await rollMenu(t, 'Edit roll');
    await settle(t);
    final camera = find.text('Canon A-1').last;
    await t.ensureVisible(camera);
    await t.tap(camera);
    await t.pumpAndSettle();
    expect(find.text('Pentax 67'), findsNothing);
    await t.tap(find.text('Nikon FM2').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    await settle(t);
    await t.pumpAndSettle();
    expect(rolls.active!.bodyId, 'nikon-fm2');
    expect(
      [for (final f in rolls.activeFrames) f.bodyId],
      ['nikon-fm2', 'canon-ae1'],
    );
    expect(
      find.text('Nikon FM2 → Canon AE-1 · 36 frames · first frame 1'),
      findsOneWidget,
    );
  });

  testWidgets('box speed roll shows the box speed line', (t) async {
    await start(t);
    await pumpScreen(t);
    expect(find.text('Box speed · ISO 400'), findsOneWidget);
  });

  testWidgets('overrun frames carry +k', (t) async {
    await start(t, size: 2, n: 4);
    await pumpScreen(t);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('ISO different from the roll is marked', (t) async {
    await start(
      t,
      pushThirds: 3,
      n: 2,
      exposure: (i) => Exposure(iso: i == 0 ? 1600 : 800),
    );
    final handle = t.ensureSemantics();
    await pumpScreen(t);
    expect(
      find.bySemanticsLabel('ISO 1600, differs from the roll'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('ISO 800'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('missing snapshot file shows the placeholder', (t) async {
    snap = _Snap.ghost;
    await start(t, n: 1);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    final name = rolls.activeFrames.single.snapshot;
    expect(name, isNotNull);
    expect(rolls.snapshots.file(name!).existsSync(), isFalse);
    await pumpScreen(t);
    // The image load fails on disk; give it real time, then repaint.
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    await t.pump();
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('insert blank before frame 2', (t) async {
    await start(t);
    await pumpScreen(t);
    await rowMenu(t, '2', 'Insert blank before');
    expect(labels(t), ['1', '2', '3', '4']);
    expect(rolls.activeFrames[1].exposure.isBlank, isTrue);
    expect(find.text('Blank'), findsOneWidget);
    final blankY = t.getTopLeft(find.text('Blank')).dy;
    expect(blankY, greaterThan(t.getTopLeft(find.text('1')).dy));
    expect(blankY, lessThan(t.getTopLeft(find.text('4')).dy));
  });

  testWidgets('a skipped frame shows as blank, with its lens', (t) async {
    await start(t, n: 1);
    await t.runAsync(
      () => rolls.skipFrame(
        lens: const Exposure(lensName: 'Canon FD 50mm f/1.8', focal: 50),
      ),
    );
    await pumpScreen(t);
    expect(labels(t), ['1', '2']);
    expect(find.text('Blank'), findsOneWidget);
    expect(find.textContaining('50 mm'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('Blank')).dy,
      greaterThan(t.getTopLeft(find.text('f/5.6 · 1/125')).dy),
    );
  });

  testWidgets('delete frame moves later frames down', (t) async {
    await start(t);
    await pumpScreen(t);
    await t.tap(find.byTooltip('Frame 2 actions'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete frame'));
    await t.pumpAndSettle();
    expect(
      find.text('Delete frame 2? Later frames move down by one.'),
      findsOneWidget,
    );
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    await settle(t);
    expect(labels(t), ['1', '2']);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('renumber from here to 00', (t) async {
    await start(t);
    await pumpScreen(t);
    await t.tap(find.byTooltip('Frame 1 actions'));
    await t.pumpAndSettle();
    await t.tap(find.text('Renumber from here…'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'x');
    await t.tap(find.text('Renumber'));
    await t.pumpAndSettle();
    expect(find.text('Use 00, 0 or a number'), findsOneWidget);
    await t.enterText(find.byType(TextField), '00');
    await t.tap(find.text('Renumber'));
    await t.pumpAndSettle();
    await settle(t);
    expect(labels(t), ['00', '0', '1']);
    expect(find.text('00'), findsOneWidget);
  });

  testWidgets('delete snapshot removes the file and the thumb', (t) async {
    snap = _Snap.written;
    await start(t, n: 0);
    await t.runAsync(() async {
      await rolls.logFrame(const Exposure(aperture: 8));
      // Let the fake snapshot land.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    final name = rolls.activeFrames.single.snapshot;
    expect(name, isNotNull);
    expect(rolls.snapshots.file(name!).existsSync(), isTrue);
    await pumpScreen(t);
    await rowMenu(t, '1', 'Delete snapshot');
    expect(rolls.activeFrames.single.snapshot, isNull);
    expect(rolls.snapshots.file(name).existsSync(), isFalse);
    await t.tap(find.byTooltip('Frame 1 actions'));
    await t.pumpAndSettle();
    expect(find.text('Delete snapshot'), findsNothing);
  });

  testWidgets('finish roll', (t) async {
    await start(t);
    await pumpScreen(t);
    await t.tap(find.byTooltip('Roll actions'));
    await t.pumpAndSettle();
    await t.tap(find.text('Finish roll'));
    await t.pumpAndSettle();
    expect(find.text('Finish roll 1?'), findsOneWidget);
    await t.tap(find.text('Finish'));
    await t.pumpAndSettle();
    await settle(t);
    expect(rolls.rolls.single.status, RollStatus.finished);
    await t.tap(find.byTooltip('Roll actions'));
    await t.pumpAndSettle();
    expect(find.text('Finish roll'), findsNothing);
    expect(find.text('Edit roll'), findsOneWidget);
  });

  testWidgets('delete roll asks with the frame count', (t) async {
    await start(t);
    await pumpScreen(t);
    await rollMenu(t, 'Delete roll');
    expect(find.text('Delete roll 1 and its 3 frames?'), findsOneWidget);
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    await settle(t);
    expect(rolls.rolls, isEmpty);
  });
}

String _dirOf(RollController r) => r.snapshots.dir.path;

enum _Snap { none, written, ghost }
