import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/solver.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/meter/meter_screen.dart';
import 'package:grain/meter/widgets/viewfinder.dart';
import 'package:grain/metering/fov.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/ui/dial/swipe_dial.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_source.dart';

class FakeHaptics implements Haptics {
  final ticks = <bool>[];
  @override
  void tick({required bool strong}) => ticks.add(strong);
}

/// Stats giving EV100 = 15 (f/1, 1/32768 s, ISO 100, region == frame).
MeterStats ev15({
  int exposureNs = 30518,
  int sensitivity = 100,
  double luma = .18,
}) => MeterStats.fromMap({
  'exposureNs': exposureNs,
  'sensitivity': sensitivity,
  'boost': 100,
  'aperture': 1.0,
  'minExposureNs': 10000,
  'maxExposureNs': 1000000000,
  'minIso': 50,
  'maxIso': 3200,
  'frameLuma': luma,
  'cropLuma': luma,
  'spotLuma': luma,
  'histogram': List<int>.filled(64, 0),
});

int labelIndex(List<dynamic> scale, String label) =>
    scale.indexWhere((v) => v.label == label);

Future<void> loadFonts() async {
  final loader = FontLoader('InterTight');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/InterTight-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(loadFonts);

  late FakeMeterSource src;
  late FakeHaptics haptics;
  late MeterController c;
  var permissionRequests = 0;
  var grant = true;

  setUp(() {
    src = FakeMeterSource(textureId: 7);
    haptics = FakeHaptics();
    c = MeterController(source: src);
    permissionRequests = 0;
    grant = true;
  });
  tearDown(() => c.dispose());

  /// Pumps the screen at the mockup's phone size, starts the camera and, if
  /// [stats] is given, delivers one frame of them.
  Future<void> pumpScreen(WidgetTester t, {MeterStats? stats}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: MeterScreen(
          controller: c,
          haptics: haptics,
          gear: GearController.inMemory(),
          requestCameraPermission: () async {
            permissionRequests++;
            return grant;
          },
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

  Color? colorOf(WidgetTester t, String text) =>
      t.widget<Text>(find.text(text)).style?.color;

  testWidgets('aperture priority shows metered shutter in accent', (t) async {
    c.setIso(labelIndex(c.isos, '100'));
    c.setAperture(labelIndex(c.apertures, '16'));
    await pumpScreen(t, stats: ev15());

    expect(find.text('1/125'), findsOneWidget);
    expect(colorOf(t, '1/125'), GrainColors.accent);
    expect(find.text('● METERED'), findsOneWidget);
    expect(find.text('← swipe →'), findsOneWidget);
    expect(
      t.widget<SwipeDial>(find.byType(SwipeDial)).values.first.label,
      'f/1',
    );
    expect(find.text('f/16'), findsOneWidget);
  });

  testWidgets('switching to Shutter priority swaps dial and result', (t) async {
    c.setIso(labelIndex(c.isos, '100'));
    await pumpScreen(t, stats: ev15());

    await t.tap(find.text('Shutter priority'));
    await t.pump();

    expect(c.mode, MeterMode.shutterPriority);
    expect(find.byType(SwipeDial), findsOneWidget);
    expect(
      t.widget<SwipeDial>(find.byType(SwipeDial)).values.first.label,
      '1/8000',
    );
    // EV15, ISO 100, 1/125 → f/16.
    expect(colorOf(t, 'f/16'), GrainColors.accent);
  });

  testWidgets('manual shows both dials and offset text', (t) async {
    c.setIso(labelIndex(c.isos, '100'));
    c.setAperture(labelIndex(c.apertures, '16'));
    c.setShutter(labelIndex(c.shutters, '1/60'));
    await pumpScreen(t, stats: ev15());

    await t.tap(find.text('Manual'));
    await t.pump();

    expect(find.byType(SwipeDial), findsNWidgets(2));
    expect(find.text('● METERED'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('viewfinder toggle hides Texture and enlarges numerals', (
    t,
  ) async {
    await pumpScreen(t, stats: ev15());
    expect(find.byType(Texture), findsOneWidget);
    expect(t.widget<Texture>(find.byType(Texture)).textureId, 7);
    expect(t.widget<SwipeDial>(find.byType(SwipeDial)).valueFontSize, 64);

    await t.tap(find.byIcon(Icons.visibility));
    await t.pump();

    expect(c.viewfinderOn, isFalse);
    expect(find.byType(Texture), findsNothing);
    expect(t.widget<SwipeDial>(find.byType(SwipeDial)).valueFontSize, 92);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('camera denied shows Allow camera and dials still work', (
    t,
  ) async {
    src.startError = PlatformException(code: 'denied');
    await pumpScreen(t);

    expect(c.cameraDenied, isTrue);
    expect(
      find.text('Grain needs the camera to measure light.'),
      findsOneWidget,
    );
    expect(find.text('Allow camera'), findsOneWidget);
    expect(find.byType(Texture), findsNothing);

    final before = c.apertureIndex;
    final g = await t.startGesture(t.getCenter(find.byType(SwipeDial)));
    await g.moveBy(const Offset(-40, 0));
    await t.pump();
    await g.up();
    await t.pump();
    expect(c.apertureIndex, before + 1);
    expect(haptics.ticks, hasLength(1));

    // With the viewfinder off the explanation stays above the rows.
    await t.tap(find.byIcon(Icons.visibility));
    await t.pump();
    expect(
      find.text('Grain needs the camera to measure light.'),
      findsOneWidget,
    );

    // Granting restarts the camera.
    src.startError = null;
    await t.tap(find.text('Allow camera'));
    await t.pump();
    await t.pump();
    expect(permissionRequests, 1);
    expect(src.calls.where((e) => e == 'start'), hasLength(2));
    expect(c.cameraDenied, isFalse);
    expect(find.text('Allow camera'), findsNothing);
  });

  testWidgets('refused permission keeps the explanation', (t) async {
    src.startError = PlatformException(code: 'denied');
    grant = false;
    await pumpScreen(t);
    await t.tap(find.text('Allow camera'));
    await t.pump();
    expect(permissionRequests, 1);
    expect(src.calls.where((e) => e == 'start'), hasLength(1));
    expect(find.text('Allow camera'), findsOneWidget);
  });

  testWidgets('camera error shows message, dials still there', (t) async {
    src.startError = PlatformException(code: 'camera_error', message: 'busy');
    await pumpScreen(t);
    expect(find.text('Camera unavailable'), findsOneWidget);
    expect(find.text('busy'), findsOneWidget);
    expect(find.text('Allow camera'), findsNothing);
    expect(find.byType(SwipeDial), findsOneWidget);
  });

  testWidgets('over-range shows ▲ over', (t) async {
    c.setIso(labelIndex(c.isos, '12800'));
    c.setAperture(0); // f/1 at EV15 ISO 12800 needs ~1/4 000 000 s.
    await pumpScreen(t, stats: ev15());
    expect(find.text('1/8000'), findsOneWidget);
    expect(find.text('▲ over'), findsOneWidget);
    expect(colorOf(t, '▲ over'), GrainColors.accent);
  });

  testWidgets('under-range shows ▼ under', (t) async {
    // EV 9 at ISO 6 and 1/8000 needs about f/0.06.
    c.setMode(MeterMode.shutterPriority);
    c.setIso(labelIndex(c.isos, '6'));
    c.setShutter(labelIndex(c.shutters, '1/8000'));
    await pumpScreen(t, stats: ev15(exposureNs: 30518 * 64));
    expect(find.text('f/1'), findsOneWidget);
    expect(find.text('▼ under'), findsOneWidget);
  });

  testWidgets('EV pill shows — before a reading, then EV, area and hold', (
    t,
  ) async {
    await pumpScreen(t);
    expect(find.text('EV — · AVG'), findsOneWidget);

    src.emit(ev15());
    await t.pump();
    await t.pump();
    expect(find.text('EV 15.0 · AVG'), findsOneWidget);

    await t.tap(find.byIcon(Icons.lock_open));
    await t.pump();
    expect(c.held, isTrue);
    expect(find.text('EV 15.0 · HELD'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('tap on the preview sets spot, long-press returns to average', (
    t,
  ) async {
    await pumpScreen(t, stats: ev15());
    final box = t.getRect(find.byType(Viewfinder));
    await t.tapAt(box.center);
    await t.pump();
    expect(c.area, MeterArea.spot);
    expect(c.spot.dx, closeTo(.5, .01));
    expect(c.spot.dy, closeTo(.5, .01));
    expect(find.text('EV 15.0 · SPOT'), findsOneWidget);

    await t.longPressAt(box.center);
    await t.pump();
    expect(c.area, MeterArea.average);
  });

  testWidgets('ISO stepper steps the scale with a haptic tick', (t) async {
    await pumpScreen(t, stats: ev15());
    expect(find.text('400'), findsOneWidget);
    await t.tap(find.byIcon(Icons.add));
    await t.pump();
    expect(c.isos[c.isoIndex].label, '500');
    expect(find.text('500'), findsOneWidget);
    await t.tap(find.byIcon(Icons.remove));
    await t.pump();
    await t.tap(find.byIcon(Icons.remove));
    await t.pump();
    expect(c.isos[c.isoIndex].label, '320');
    expect(haptics.ticks, [false, true, false]);
  });

  testWidgets('focal chip opens a dial that changes the focal length', (
    t,
  ) async {
    await pumpScreen(t, stats: ev15());
    expect(find.text('50 mm'), findsOneWidget);
    await t.tap(find.text('50 mm'));
    await t.pumpAndSettle();
    final dial = find.byType(SwipeDial).last;
    final g = await t.startGesture(t.getCenter(dial));
    await g.moveBy(const Offset(-40, 0));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(focalStops[c.focalIndex], 55);
    expect(find.text('55 mm'), findsWidgets);
  });

  testWidgets('wider lens than the phone shows a note', (t) async {
    c.setFocal(0); // 12 mm against a 25 mm phone camera.
    await pumpScreen(t, stats: ev15());
    expect(find.text('Wider than this camera'), findsOneWidget);
  });

  testWidgets('manual: live stats within the same third do not rebuild dials', (
    t,
  ) async {
    c.setIso(labelIndex(c.isos, '100'));
    c.setAperture(labelIndex(c.apertures, '16'));
    c.setShutter(labelIndex(c.shutters, '1/60'));
    c.setMode(MeterMode.manual);
    await pumpScreen(t, stats: ev15());
    expect(find.text('+1'), findsOneWidget);
    final before = t.widgetList<SwipeDial>(find.byType(SwipeDial)).toList();

    // ~0.1 stop brighter: still rounds to +1.
    src.emit(ev15(exposureNs: 28500));
    await t.pump();
    expect(c.reading!.ev100, isNot(closeTo(15, .05)));
    final after = t.widgetList<SwipeDial>(find.byType(SwipeDial)).toList();
    expect(after, hasLength(2));
    for (var i = 0; i < 2; i++) {
      expect(identical(before[i], after[i]), isTrue, reason: 'dial $i');
    }
    expect(find.text('+1'), findsOneWidget);

    // A full stop brighter moves the offset text without touching the dials.
    src.emit(ev15(exposureNs: 30518 ~/ 2));
    await t.pump();
    expect(find.text('+2'), findsOneWidget);
    final later = t.widgetList<SwipeDial>(find.byType(SwipeDial)).toList();
    expect(identical(before[0], later[0]), isTrue);
  });

  testWidgets('phone AE over range flags the EV pill with ▲', (t) async {
    // At min exposure and min ISO with near-white luma (reading.dart rules).
    await pumpScreen(
      t,
      stats: ev15(exposureNs: 10000, sensitivity: 50, luma: .95),
    );
    expect(c.reading!.flag, RangeFlag.over);
    expect(find.text('EV 17.6 ▲ · AVG'), findsOneWidget);

    // Still visible with the viewfinder off.
    await t.tap(find.byIcon(Icons.visibility));
    await t.pump();
    expect(find.text('EV 17.6 ▲ · AVG'), findsOneWidget);
  });

  testWidgets('phone AE under range flags the EV pill with ▼', (t) async {
    // At max exposure and max ISO with near-black luma.
    await pumpScreen(
      t,
      stats: ev15(exposureNs: 1000000000, sensitivity: 3200, luma: .005),
    );
    expect(c.reading!.flag, RangeFlag.under);
    expect(find.text('EV −5.0 ▼ · AVG'), findsOneWidget);

    await t.tap(find.byIcon(Icons.visibility));
    await t.pump();
    expect(find.text('EV −5.0 ▼ · AVG'), findsOneWidget);
  });

  testWidgets('viewfinder off shows the EV line without a flag', (t) async {
    await pumpScreen(t, stats: ev15());
    await t.tap(find.byIcon(Icons.visibility));
    await t.pump();
    expect(find.text('EV 15.0 · AVG'), findsOneWidget);
  });

  testWidgets('header shows profile and mode', (t) async {
    await pumpScreen(t);
    expect(find.text('No camera'), findsOneWidget);
    expect(find.text('Free mode'), findsOneWidget);
    expect(find.text('Aperture priority'), findsOneWidget);
  });
}
