import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/gear/gear_scales.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/metering/reading.dart';

import '../support/fake_source.dart';
import '../support/gear_fixtures.dart';

/// Stats giving exactly [ev100] (f/1, ISO 100, region == frame).
MeterStats statsAt(double ev100) => MeterStats.fromMap({
  'exposureNs': (1e9 * math.pow(2, -ev100)).round(),
  'sensitivity': 100,
  'boost': 100,
  'aperture': 1.0,
  'minExposureNs': 10000,
  'maxExposureNs': 100000000000,
  'minIso': 50,
  'maxIso': 3200,
  'frameLuma': .18,
  'cropLuma': .18,
  'spotLuma': .18,
  'histogram': List<int>.filled(64, 0),
});

void main() {
  late FakeMeterSource src;
  late MeterController c;
  final a1 = libBody('canon-a1');
  final ae1 = libBody('canon-ae1');
  final yashica = libBody('yashica-mat-124g');
  final fd50 = libLens('canon-fd-50-1.8');
  final yashinon = libLens('yashinon-80-3.5');

  String isoLabel() => c.isos[c.isoIndex].label;

  setUp(() {
    src = FakeMeterSource();
    c = MeterController(source: src);
  });
  tearDown(() => c.dispose());

  /// Resumes and feeds one reading of [ev].
  Future<void> reading(double ev) async {
    await c.resume();
    src.emit(statsAt(ev));
    await pumpEventQueue();
  }

  test('roll ISO sets the meter and marks a change', () {
    c.setGear(GearSetup(body: a1, lens: fd50, focal: 50));
    c.setRollIso(800);
    expect(isoLabel(), '800');
    expect(c.isoDiffersFromRoll, isFalse);
    c.setIso(c.isoIndex + 1);
    expect(isoLabel(), '1000');
    expect(c.isoDiffersFromRoll, isTrue);
    // Same ISO again changes nothing, the stepped value stays.
    var notified = 0;
    c.addListener(() => notified++);
    c.setRollIso(800);
    expect(notified, 0);
    expect(isoLabel(), '1000');
  });

  test('exposed ISO beyond the body dial extends the scale', () {
    final g = GearSetup(body: yashica, lens: yashinon, focal: 80);
    c.setGear(g);
    expect(c.isos.last.label, '400');
    c.setRollIso(1600);
    expect(c.isos.last.label, '1600');
    expect(c.isos[c.isoIndex].label, '1600');
    expect(c.captureExposure().iso, 1600);
    expect(c.isoDiffersFromRoll, isFalse);
    // setGear with an equal gear is a no-op, so switch away and back.
    c.setGear(GearSetup(body: a1, lens: fd50, focal: 50));
    c.setGear(g);
    expect(c.isos.last.label, '1600');
    expect(c.isos[c.isoIndex].label, '1600');
    // A focal change keeps the extension too.
    c.setFocal(0);
    expect(c.isos.last.label, '1600');
  });

  test('releasing the roll ISO restores the gear scale, nearest value', () {
    c.setGear(GearSetup(body: yashica, lens: yashinon, focal: 80));
    c.setRollIso(1600);
    c.setRollIso(null);
    expect(c.isos.last.label, '400');
    expect(isoLabel(), '400');
    expect(c.isoDiffersFromRoll, isFalse);
  });

  test(
    'capture in aperture priority logs the solved shutter, nominal',
    () async {
      c.setGear(GearSetup(body: a1, lens: fd50, focal: 50));
      c.setIso(c.isos.indexWhere((v) => v.label == '100'));
      c.setAperture(c.apertures.indexWhere((v) => v.label == '4'));
      await reading(12);
      final e = c.captureExposure();
      expect(e.mode, MeterMode.aperturePriority);
      expect(e.shutter, '1/250');
      expect(e.exposureTime, .004);
      expect(e.aperture, 4.0);
      expect(e.iso, 100);
      expect(e.meteredEv, closeTo(12, 1e-3));
      expect(e.lensId, fd50.id);
      expect(e.lensMake, fd50.make);
      expect(e.lensName, fd50.name);
      expect(e.focal, 50);
      expect(e.offset, isNull);
      expect(e.area, c.area);
    },
  );

  test('capture in shutter priority logs the solved aperture', () async {
    c.setMode(MeterMode.shutterPriority);
    c.setIso(c.isos.indexWhere((v) => v.label == '100'));
    c.setShutter(c.shutters.indexWhere((v) => v.label == '1/250'));
    await reading(12);
    final e = c.captureExposure();
    expect(e.shutter, '1/250');
    expect(e.exposureTime, .004);
    expect(e.aperture, 4.0);
    expect(e.mode, MeterMode.shutterPriority);
  });

  test('capture without a reading leaves solved values empty', () {
    final e = c.captureExposure();
    expect(e.shutter, isNull);
    expect(e.exposureTime, isNull);
    expect(e.meteredEv, isNull);
    expect(e.aperture, 5.6);
    expect(e.iso, 400);
    expect(e.lensId, isNull);
  });

  test('capture in Bulb', () async {
    c.setIso(c.isos.indexWhere((v) => v.label == '100'));
    c.setAperture(c.apertures.indexWhere((v) => v.label == '4'));
    await reading(-2);
    final e = c.captureExposure();
    expect(e.shutter, 'B');
    expect(e.exposureTime, 64.0);
    expect(e.aperture, 4.0);
  });

  test('capture in manual records the offset', () async {
    c.setGear(GearSetup(body: ae1, lens: fd50, focal: 50));
    c.setMode(MeterMode.manual);
    c.setIso(c.isos.indexWhere((v) => v.label == '100'));
    c.setAperture(c.apertures.indexWhere((v) => v.label == '4'));
    c.setShutter(c.shutters.indexWhere((v) => v.label == '1/125'));
    await reading(12);
    final e = c.captureExposure();
    expect(e.mode, MeterMode.manual);
    expect(e.shutter, '1/125');
    expect(e.exposureTime, 1 / 125);
    expect(e.aperture, 4.0);
    // 1/250 is right, 1/125 gives one stop more light.
    expect(e.offset, closeTo(1, .05));
    expect(e.meteredEv, closeTo(12, 1e-3));
  });
}
