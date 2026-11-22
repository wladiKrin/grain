import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/main.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/meter/meter_screen.dart';
import 'package:grain/meter/widgets/focal_chip.dart';
import 'package:grain/meter/widgets/lens_chip.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/ui/dial/swipe_dial.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_source.dart';
import '../support/rolls_fixtures.dart';
import '../support/gear_fixtures.dart';

class _Haptics implements Haptics {
  final ticks = <bool>[];
  @override
  void tick({required bool strong}) => ticks.add(strong);
}

/// Stats giving EV100 = -2 (f/1, 4 s, ISO 100).
MeterStats evMinus2() => MeterStats.fromMap({
  'exposureNs': 4000000000,
  'sensitivity': 100,
  'boost': 100,
  'aperture': 1.0,
  'minExposureNs': 10000,
  'maxExposureNs': 10000000000,
  'minIso': 50,
  'maxIso': 3200,
  'frameLuma': .18,
  'cropLuma': .18,
  'spotLuma': .18,
  'histogram': List<int>.filled(64, 0),
});

Future<void> _loadFonts() async {
  final loader = FontLoader('InterTight');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/InterTight-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  late GearController gear;
  late MeterController c;
  late FakeMeterSource src;
  late _Haptics haptics;
  var pickerOpened = 0;

  setUp(() {
    gear = GearController.inMemory(library: fixtureLibrary());
    src = FakeMeterSource();
    haptics = _Haptics();
    c = MeterController(source: src, gear: gear.setup);
    // The same sync GrainApp does.
    gear.addListener(() => c.setGear(gear.setup));
    pickerOpened = 0;
  });
  tearDown(() {
    c.dispose();
    gear.dispose();
  });

  Future<void> pumpScreen(WidgetTester t, {MeterStats? stats}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: MeterScreen(
          controller: c,
          rolls: inMemoryRolls(),
          gear: gear,
          haptics: haptics,
          onOpenLensPicker: () => pickerOpened++,
        ),
      ),
    );
    await c.resume();
    if (stats != null) {
      src.emit(stats);
      await t.pump();
    }
    await t.pump();
  }

  Future<void> select(WidgetTester t, {String? body, String? lens}) async {
    if (body != null) await t.runAsync(() => gear.selectBody(libBody(body)));
    if (lens != null) await t.runAsync(() => gear.selectLens(libLens(lens)));
    await t.pump();
  }

  testWidgets('header shows the body and its format', (t) async {
    await pumpScreen(t);
    expect(find.text('No camera'), findsOneWidget);
    expect(find.text('Free mode'), findsOneWidget);
    await select(t, body: 'canon-a1');
    expect(find.text('Canon A-1'), findsOneWidget);
    expect(find.text('35 mm'), findsOneWidget);
    expect(find.text('No camera'), findsNothing);
  });

  testWidgets('No camera shows only the focal chip', (t) async {
    await pumpScreen(t);
    expect(find.byType(LensChip), findsNothing);
    expect(find.byType(FocalChip), findsOneWidget);
    expect(find.text('50 mm'), findsOneWidget);
  });

  testWidgets('lens chip shows the lens and cycles favorites', (t) async {
    await t.runAsync(() async {
      await gear.toggleFavorite(libLens('canon-fd-28-2.8'));
      await gear.toggleFavorite(libLens('canon-fd-50-1.8'));
    });
    await select(t, body: 'canon-a1');
    await pumpScreen(t);
    expect(find.text('FD 28/2.8'), findsOneWidget);
    await t.tap(find.text('FD 28/2.8'));
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump();
    expect(find.text('FD 50/1.8'), findsOneWidget);
    expect(haptics.ticks, [false]);
    expect(pickerOpened, 0);
  });

  testWidgets('lens chip without favorites opens the lens picker', (t) async {
    await select(t, body: 'canon-a1');
    await pumpScreen(t);
    expect(find.text('Choose lens'), findsOneWidget);
    await t.tap(find.text('Choose lens'));
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump();
    expect(pickerOpened, 1);
    expect(haptics.ticks, isEmpty);
  });

  testWidgets('more… opens the lens picker', (t) async {
    await select(t, body: 'canon-a1', lens: 'canon-fd-50-1.8');
    await pumpScreen(t);
    await t.tap(find.text('more…'));
    await t.pump();
    expect(pickerOpened, 1);
  });

  testWidgets('prime hides the focal chip, zoom shows its range', (t) async {
    await select(t, body: 'canon-a1', lens: 'canon-fd-50-1.8');
    await pumpScreen(t);
    expect(find.byType(FocalChip), findsNothing);

    await select(t, lens: 'canon-fd-35-70-3.5-4.5');
    expect(find.byType(FocalChip), findsOneWidget);
    expect(find.text('50 mm'), findsOneWidget);
    await t.tap(find.text('50 mm'));
    await t.pumpAndSettle();
    final dial = t.widget<SwipeDial>(find.byType(SwipeDial).last);
    expect(dial.values.first.label, '35');
    expect(dial.values.last.label, '70');
  });

  testWidgets('aperture dial offers only the lens apertures', (t) async {
    await pumpScreen(t);
    expect(
      t.widget<SwipeDial>(find.byType(SwipeDial).first).values.first.label,
      'f/1',
    );
    await select(t, body: 'canon-a1', lens: 'canon-fd-50-1.8');
    final dial = t.widget<SwipeDial>(find.byType(SwipeDial).first);
    expect(dial.values.first.label, 'f/1.8');
    expect(dial.values.map((v) => v.label), isNot(contains('f/1')));
    // Drag right to the wide end.
    final g = await t.startGesture(t.getCenter(find.byType(SwipeDial).first));
    await g.moveBy(const Offset(600, 0));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(c.apertures[c.apertureIndex].label, '1.8');
    expect(find.text('f/1.8'), findsWidgets);
  });

  testWidgets('Bulb result shows B and the time', (t) async {
    c.setIso(c.isos.indexWhere((v) => v.label == '100'));
    c.setAperture(c.apertures.indexWhere((v) => v.label == '4'));
    await pumpScreen(t, stats: evMinus2());
    expect(c.bulbSeconds, closeTo(64, 1));
    expect(find.text('B'), findsOneWidget);
    expect(
      t.widget<Text>(find.text('B')).style?.color,
      GrainPalette.light.accent,
    );
    expect(find.text('1m 04s'), findsOneWidget);
  });

  testWidgets('library button and title open the library', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.runAsync(() => gear.selectBody(libBody('canon-a1')));
    await t.pumpWidget(
      GrainApp(
        source: FakeMeterSource(logRegions: false),
        haptics: haptics,
        gear: gear,
      ),
    );
    await t.pump();

    await t.tap(find.byIcon(Icons.photo_camera_outlined));
    await t.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    await t.tap(find.byIcon(Icons.arrow_back));
    await t.pumpAndSettle();
    expect(find.text('Library'), findsNothing);

    await t.tap(find.text('Canon A-1'));
    await t.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
  });
}
