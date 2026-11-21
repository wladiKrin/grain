import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/exposure/solver.dart';
import 'package:grain/gear/gear_scales.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/metering/fov.dart';
import 'package:grain/metering/meter_channel.dart';
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
  'maxExposureNs': 1000000000,
  'minIso': 50,
  'maxIso': 3200,
  'frameLuma': .18,
  'cropLuma': .18,
  'spotLuma': .18,
  'histogram': List<int>.filled(64, 0),
});

Future<void> settle() => pumpEventQueue();

int idx(List<ScaleValue> s, String label) {
  final i = s.indexWhere((v) => v.label == label);
  if (i < 0) throw StateError('no $label in ${s.map((v) => v.label)}');
  return i;
}

void main() {
  late FakeMeterSource src;
  late MeterController c;

  final a1 = libBody('canon-a1');
  final ae1 = libBody('canon-ae1');
  final k1000 = libBody('pentax-k1000');
  final yashica = libBody('yashica-mat-124g');
  final fd50 = libLens('canon-fd-50-1.8');
  final fd3570 = libLens('canon-fd-35-70-3.5-4.5');
  final yashinon = libLens('yashinon-80-3.5');

  String apLabel() => c.apertures[c.apertureIndex].label;
  String shLabel() => c.shutters[c.shutterIndex].label;
  String isoLabel() => c.isos[c.isoIndex].label;

  setUp(() {
    src = FakeMeterSource(
      size: const Size(4000, 3000),
      mainEqFocal: 25,
      wideEqFocal: 13,
    );
    c = MeterController(source: src);
  });
  tearDown(() => c.dispose());

  test('free gear by default: plan-1 scales and defaults', () {
    expect(c.gear, const GearSetup());
    expect(c.format, FilmFormat.f135);
    expect(c.hasBulb, isTrue);
    expect(c.focal, 50);
    expect(c.focalValues.map((v) => v.value), [
      for (final f in focalStops) f.toDouble(),
    ]);
    expect(c.focalValues[c.focalIndex].value, 50);
    expect(apLabel(), '5.6');
    expect(shLabel(), '1/125');
    expect(isoLabel(), '400');
  });

  test('initial indices snap to the nearest value of the given gear', () {
    final g = GearSetup(body: ae1, lens: fd3570, focal: 70);
    final m = MeterController(source: src, gear: g);
    addTearDown(m.dispose);
    expect(m.gear, g);
    expect(m.focal, 70);
    expect(m.apertures.first.label, '4.5');
    expect(m.apertures[m.apertureIndex].label, '5.6');
    expect(m.shutters[m.shutterIndex].label, '1/125');
    expect(m.isos[m.isoIndex].label, '400');
    // A camera whose ISO range ends below the default: nearest, not -1.
    final y = MeterController(
      source: src,
      gear: GearSetup(body: yashica, lens: yashinon, focal: 80),
    );
    addTearDown(y.dispose);
    expect(y.isos[y.isoIndex].label, '400');
    expect(y.shutters[y.shutterIndex].label, '1/125');
    expect(y.apertures[y.apertureIndex].label, '5.6');
    expect(y.focal, 80);
    expect(y.format, FilmFormat.f66);
  });

  test('gear switch keeps values the new gear has', () {
    var notified = 0;
    c.addListener(() => notified++);
    c.setGear(GearSetup(body: a1, lens: fd50, focal: 50));
    expect(notified, 1);
    expect(apLabel(), '5.6');
    expect(shLabel(), '1/125');
    expect(isoLabel(), '400');
    expect(c.focal, 50);
    expect(c.focalValues.map((v) => v.label), ['50']);
    expect(c.apertures.first.label, '1.8');
    expect(c.shutters.first.label, '1/1000');
    expect(c.shutters.last.label, '30"');
  });

  test('gear switch snaps off-scale values to the nearest', () async {
    c.setShutter(idx(c.shutters, '1/4000'));
    c.setAperture(idx(c.apertures, '1.4'));
    c.setIso(idx(c.isos, '12800'));
    c.setGear(GearSetup(body: ae1, lens: fd50, focal: 50));
    expect(shLabel(), '1/1000');
    expect(apLabel(), '1.8');
    expect(isoLabel(), '3200');
    for (final i in [c.apertureIndex, c.shutterIndex, c.isoIndex]) {
      expect(i, greaterThanOrEqualTo(0));
    }
    await c.resume();
    src.emit(statsAt(12));
    await settle();
    final solved = c.solvedShutter;
    expect(solved, isNotNull);
    expect(solved!.index, inInclusiveRange(0, c.shutters.length - 1));
  });

  test('gear switch remaps the focal length to the new lens', () {
    c.setFocal(idx(c.focalValues, '135'));
    c.setGear(GearSetup(body: a1, lens: fd3570, focal: 135));
    expect(c.focal, 70);
    expect(c.apertures.first.label, '4.5');
    c.setGear(GearSetup(body: a1, focal: 24));
    expect(c.focal, 24);
    expect(c.apertures.first.label, '1');
  });

  test('zooming a varying-aperture zoom wide open', () {
    c.setGear(GearSetup(body: a1, lens: fd3570, focal: 35));
    c.setAperture(idx(c.apertures, '3.5'));
    expect(c.apertures.first.label, '3.5');

    c.setFocal(idx(c.focalValues, '70'));
    expect(c.focal, 70);
    expect(c.apertures.first.label, '4.5');
    expect(apLabel(), '4.5');

    // Back at 35 mm the aperture is not reopened to f/3.5: the half-stop
    // grid at 35 mm has no f/4.5, so it stays at the nearest stop to f/4.5
    // (f/4.8, 0.16 stop away).
    c.setFocal(idx(c.focalValues, '35'));
    expect(c.focal, 35);
    expect(c.apertures.first.label, '3.5');
    expect(apLabel(), isNot('3.5'));
    expect(apLabel(), '4.8');
    expect(
      (math.log(c.apertures[c.apertureIndex].value / 4.5) / math.ln2).abs() * 2,
      lessThan(1 / 3),
    );

    // And at 70 mm again it is f/4.5, no drift.
    c.setFocal(idx(c.focalValues, '70'));
    expect(apLabel(), '4.5');
  });

  test(
    'setFocal stores the focal in the gear (round trip is a no-op)',
    () async {
      c.setGear(GearSetup(body: a1, lens: fd3570, focal: 35));
      await c.resume();
      c.setFocal(idx(c.focalValues, '50'));
      expect(c.gear, GearSetup(body: a1, lens: fd3570, focal: 50));
      final regionsBefore = src.regions.length;
      var notified = 0;
      c.addListener(() => notified++);
      c.setGear(GearSetup(body: a1, lens: fd3570, focal: 50));
      expect(notified, 0);
      expect(src.regions.length, regionsBefore);
    },
  );

  test('setGear with an equal setup does not notify', () async {
    c.setGear(GearSetup(body: a1, lens: fd50, focal: 50));
    await c.resume();
    final apertures = c.apertures;
    final regionsBefore = src.regions.length;
    final callsBefore = src.calls.length;
    var notified = 0;
    c.addListener(() => notified++);
    // An equal but not identical setup.
    c.setGear(GearSetup(body: a1.copyWith(), lens: fd50.copyWith(), focal: 50));
    await settle();
    expect(notified, 0);
    expect(c.apertures, same(apertures));
    expect(src.regions.length, regionsBefore);
    expect(src.calls.length, callsBefore);
  });

  test('setGear sends regions once and notifies once', () async {
    await c.resume();
    final regionsBefore = src.regions.length;
    var notified = 0;
    c.addListener(() => notified++);
    c.setGear(GearSetup(body: a1, lens: fd50, focal: 50));
    expect(notified, 1);
    expect(src.regions.length, regionsBefore + 1);
  });

  group('Bulb answer when the time exceeds the slowest speed', () {
    Future<void> meter(double ev100) async {
      await c.resume();
      src.emit(statsAt(ev100));
      await settle();
    }

    test('free gear: 64 s at f/4, ISO 100, EV -2', () async {
      c.setIso(idx(c.isos, '100'));
      c.setAperture(idx(c.apertures, '4'));
      await meter(-2);
      expect(c.solvedShutter!.flag, RangeFlag.under);
      expect(c.bulbSeconds, closeTo(64, 1e-6));
    });

    test('K1000 without a lens: 4 s at f/2, ISO 100, EV 0', () async {
      c.setGear(GearSetup(body: k1000));
      c.setIso(idx(c.isos, '100'));
      c.setAperture(idx(c.apertures, '2'));
      await meter(0);
      expect(c.solvedShutter!.flag, RangeFlag.under);
      expect(c.bulbSeconds, closeTo(4, 1e-6));
    });

    test('a body without B gives no Bulb answer', () async {
      final noB = k1000.copyWith(
        id: 'no-b',
        shutter: [
          '1/500',
          '1/250',
          '1/125',
          '1/60',
          '1/30',
          '1/15',
          '1/8',
          '1/4',
          '1/2',
          '1',
        ],
      );
      c.setGear(GearSetup(body: noB));
      expect(c.hasBulb, isFalse);
      c.setIso(idx(c.isos, '100'));
      c.setAperture(idx(c.apertures, '2'));
      await meter(0);
      expect(c.solvedShutter!.flag, RangeFlag.under);
      expect(c.bulbSeconds, isNull);
    });

    test(
      'no Bulb answer when the time is on the dial or outside A mode',
      () async {
        c.setIso(idx(c.isos, '100'));
        c.setAperture(idx(c.apertures, '4'));
        expect(c.bulbSeconds, isNull); // no reading yet
        await meter(4); // 1 s
        expect(c.solvedShutter!.flag, RangeFlag.ok);
        expect(c.bulbSeconds, isNull);
        src.emit(statsAt(-2));
        await settle();
        expect(c.bulbSeconds, isNotNull);
        c.setMode(MeterMode.manual);
        expect(c.bulbSeconds, isNull);
        c.setMode(MeterMode.shutterPriority);
        expect(c.bulbSeconds, isNull);
      },
    );
  });

  test('crop follows the film format', () async {
    c.setGear(GearSetup(body: yashica, lens: yashinon, focal: 80));
    await c.resume();
    final r = c.cropRect!;
    // Portrait preview is 3000 × 4000 px; a 6×6 frame is square.
    expect((r.width * 3000) / (r.height * 4000), closeTo(1, 1e-6));
    // 80 mm on 6×6 frames like ~44 mm on 135: narrower than the 25 mm phone.
    expect(r.width, lessThan(1));
    expect(c.lensWiderThanCamera, isFalse);
    expect(src.regions.last.$1, r);

    c.setGear(GearSetup(body: a1, lens: fd50, focal: 50));
    final r135 = c.cropRect!;
    expect((r135.width * 3000) / (r135.height * 4000), closeTo(2 / 3, 1e-6));
  });

  test('ultra-wide engages below the main camera and releases above', () async {
    await c.resume();
    expect(c.preview!.wide, isFalse);
    c.setFocal(idx(c.focalValues, '20'));
    await settle();
    expect(src.calls, contains('setWide(true)'));
    expect(c.preview!.wide, isTrue);
    expect(c.preview!.phoneEqFocal, 13);
    expect(c.lensWiderThanCamera, isFalse);
    // Regions resent for the ultra-wide's field of view.
    expect(src.calls.last, 'setRegions');
    final wideCrop = c.cropRect!;
    expect(src.regions.last.$1, wideCrop);

    c.setFocal(idx(c.focalValues, '24'));
    await settle();
    expect(src.calls.where((e) => e.startsWith('setWide')), ['setWide(true)']);

    c.setFocal(idx(c.focalValues, '50'));
    await settle();
    expect(src.calls.where((e) => e.startsWith('setWide')), [
      'setWide(true)',
      'setWide(false)',
    ]);
    expect(c.preview!.wide, isFalse);
    expect(c.preview!.phoneEqFocal, 25);
  });

  test('ultra-wide follows a gear change too', () async {
    await c.resume();
    c.setGear(GearSetup(body: a1, focal: 20));
    await settle();
    expect(c.preview!.wide, isTrue);
    c.setGear(GearSetup(body: a1, lens: fd50, focal: 50));
    await settle();
    expect(c.preview!.wide, isFalse);
  });

  test('a medium-format lens uses its 135 equivalent for the switch', () async {
    // 45 mm on 6×6 ≈ 25 mm on 135, which is not below the 25 mm main camera;
    // 40 mm ≈ 22 mm is.
    final zoom = fd3570.copyWith(
      id: 'mf-zoom',
      focalMin: 40,
      focalMax: 80,
      maxAperture: const [ApertureAt(40, 4), ApertureAt(80, 4)],
    );
    await c.resume();
    c.setGear(GearSetup(body: yashica, lens: zoom, focal: 80));
    await settle();
    expect(c.preview!.wide, isFalse);
    c.setFocal(idx(c.focalValues, '40'));
    await settle();
    expect(c.preview!.wide, isTrue);
  });

  test('a quick wide on → off ends on the main camera', () async {
    await c.resume();
    c.setFocal(idx(c.focalValues, '20'));
    c.setFocal(idx(c.focalValues, '50')); // while setWide(true) is in flight
    await settle();
    expect(src.calls.where((e) => e.startsWith('setWide')), [
      'setWide(true)',
      'setWide(false)',
    ]);
    expect(c.preview!.wide, isFalse);
  });

  test('only one setWide is in flight at a time', () async {
    await c.resume();
    c.setFocal(idx(c.focalValues, '20'));
    c.setFocal(idx(c.focalValues, '50'));
    c.setFocal(idx(c.focalValues, '16'));
    await settle();
    // The in-flight 'true' already matches the last wish: nothing more.
    expect(src.calls.where((e) => e.startsWith('setWide')), ['setWide(true)']);
    expect(c.preview!.wide, isTrue);
  });

  test('a failed switch leaves the main camera in use', () async {
    await c.resume();
    final main = c.preview;
    src.setWideError = PlatformException(code: 'camera_error');
    c.setFocal(idx(c.focalValues, '20'));
    await settle();
    expect(src.calls, contains('setWide(true)'));
    expect(c.preview, same(main));
    expect(c.preview!.wide, isFalse);
    expect(c.cameraError, isNull);
    // The lens is then wider than the camera in use: the note shows.
    expect(c.lensWiderThanCamera, isTrue);
    // No retry on every detent while this session runs.
    c.setFocal(idx(c.focalValues, '18'));
    await settle();
    expect(src.calls.where((e) => e.startsWith('setWide')), ['setWide(true)']);
  });

  test('a failed switch is retried after the camera restarts', () async {
    await c.resume();
    src.setWideError = PlatformException(code: 'camera_error');
    c.setFocal(idx(c.focalValues, '20'));
    await settle();
    src.setWideError = null;
    await c.pause();
    await c.resume();
    await settle();
    expect(c.preview!.wide, isTrue);
  });

  test('a switch answered with the unchanged preview is not retried', () async {
    final stuck = _StuckWideSource();
    final m = MeterController(source: stuck);
    addTearDown(m.dispose);
    await m.resume();
    m.setFocal(idx(m.focalValues, '20'));
    await settle();
    m.setFocal(idx(m.focalValues, '18'));
    await settle();
    expect(stuck.calls.where((e) => e.startsWith('setWide')), [
      'setWide(true)',
    ]);
    expect(m.preview!.wide, isFalse);
    expect(m.lensWiderThanCamera, isTrue);
  });

  test('no ultra-wide on the phone: no switch, note shown', () async {
    src = FakeMeterSource(size: const Size(4000, 3000), mainEqFocal: 25);
    final m = MeterController(source: src);
    addTearDown(m.dispose);
    await m.resume();
    m.setFocal(idx(m.focalValues, '12'));
    await settle();
    expect(src.calls.where((e) => e.startsWith('setWide')), isEmpty);
    expect(m.preview!.wide, isFalse);
    expect(m.lensWiderThanCamera, isTrue);
  });

  test('no switch while not running', () async {
    c.setFocal(idx(c.focalValues, '20'));
    await settle();
    expect(src.calls, isEmpty);
    expect(c.lensWiderThanCamera, isFalse); // no preview yet
  });

  test('resume re-applies the ultra-wide', () async {
    c.setFocal(idx(c.focalValues, '20'));
    await c.resume();
    await settle();
    expect(src.calls, ['start', 'setRegions', 'setWide(true)', 'setRegions']);
    expect(c.preview!.wide, isTrue);
    await c.pause();
    await c.resume();
    await settle();
    final last = src.calls.lastIndexOf('start');
    expect(src.calls.sublist(last), [
      'start',
      'setRegions',
      'setWide(true)',
      'setRegions',
    ]);
    expect(c.preview!.wide, isTrue);
  });

  test('pause during a switch drops its answer', () async {
    await c.resume();
    c.setFocal(idx(c.focalValues, '20')); // setWide(true) in flight
    await c.pause();
    await settle();
    expect(c.preview!.wide, isFalse);
    expect(src.calls.last, isNot('setRegions'));
  });

  test('scales match scalesFor for the snapped focal', () {
    final g = GearSetup(body: a1, lens: fd3570, focal: 52);
    c.setGear(g);
    expect(c.focal, 50);
    expect(
      c.apertures.map((v) => v.label),
      scalesFor(GearSetup(body: a1, lens: fd3570, focal: 50)).apertures
          .map((v) => v.label),
    );
    expect(c.gear, g);
  });

  group('lendCamera', () {
    List<String> calls() => [
      for (final e in src.calls)
        if (e != 'setRegions') e,
    ];

    test('keeps the meter closed while scanning', () async {
      await c.resume();
      expect(calls(), ['start']);
      final result = await c.lendCamera(() async {
        expect(calls(), ['start', 'stop']);
        await c.resume();
        expect(calls(), ['start', 'stop'], reason: 'no start while lent');
        return 42;
      });
      await settle();
      expect(result, 42);
      expect(calls(), ['start', 'stop', 'start']);
    });

    test('resumes after use throws, and rethrows', () async {
      await c.resume();
      await expectLater(
        c.lendCamera<void>(() async => throw StateError('boom')),
        throwsStateError,
      );
      await settle();
      expect(calls(), ['start', 'stop', 'start']);
    });

    test('a stop still in flight finishes before the meter restarts', () async {
      await c.resume();
      src.stopGate = Completer<void>();
      var restarted = false;
      final lend = c.lendCamera(() async {});
      await settle();
      restarted = calls().where((e) => e == 'start').length > 1;
      expect(restarted, isFalse);
      src.stopGate!.complete();
      await lend;
      await settle();
      expect(calls(), ['start', 'stop', 'start']);
    });
  });
}

/// Has an ultra-wide but answers every switch with the unchanged main preview
/// (as the native side does when a zoom-ratio switch fails).
class _StuckWideSource extends FakeMeterSource {
  _StuckWideSource()
    : super(size: const Size(4000, 3000), mainEqFocal: 25, wideEqFocal: 13);

  @override
  Future<PreviewInfo> setWide(bool wide) async {
    calls.add('setWide($wide)');
    return start().then((p) {
      calls.removeLast();
      return p;
    });
  }
}
