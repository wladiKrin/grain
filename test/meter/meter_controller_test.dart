import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/metering/fov.dart';
import 'package:grain/metering/histogram.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/rolls/latitude.dart';

import '../support/fake_source.dart';

/// Stats giving EV100 = 15 (f/1, 1/32768 s, ISO 100, region == frame).
MeterStats stats({
  double region = .18,
  int exposureNs = 30518,
  double aperture = 1.0,
  List<int>? histogram,
}) => MeterStats.fromMap({
  'exposureNs': exposureNs,
  'sensitivity': 100,
  'boost': 100,
  'aperture': aperture,
  'minExposureNs': 10000,
  'maxExposureNs': 1000000000,
  'minIso': 50,
  'maxIso': 3200,
  'frameLuma': .18,
  'cropLuma': region,
  'spotLuma': region,
  'histogram': histogram ?? List<int>.filled(64, 0),
});

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeMeterSource src;
  late MeterController c;
  setUp(() {
    src = FakeMeterSource(size: const Size(4000, 3000));
    c = MeterController(source: src);
  });
  tearDown(() => c.dispose());

  test('defaults', () {
    expect(c.mode, MeterMode.aperturePriority);
    expect(c.apertures[c.apertureIndex].label, '5.6');
    expect(c.shutters[c.shutterIndex].label, '1/125');
    expect(c.isos[c.isoIndex].label, '400');
    expect(focalStops[c.focalIndex], 50);
    expect(c.area, MeterArea.average);
    expect(c.viewfinderOn, isTrue);
    expect(c.solvedShutter, isNull);
    expect(c.offset, isNull);
  });

  Future<void> run() async {
    await c.resume();
    src.emit(stats());
    await settle();
  }

  int ap(String l) => c.apertures.indexWhere((v) => v.label == l);
  int iso(String l) => c.isos.indexWhere((v) => v.label == l);
  int sh(String l) => c.shutters.indexWhere((v) => v.label == l);

  test('aperture priority uses latest reading and ISO', () async {
    await run();
    c.setIso(iso('100'));
    c.setAperture(ap('16'));
    expect(c.reading!.ev100, closeTo(15, 1e-3));
    expect(c.shutters[c.solvedShutter!.index].label, '1/125');
    expect(c.solvedAperture, isNull);
    expect(c.offset, isNull);
  });

  test('shutter priority solves aperture', () async {
    await run();
    c.setMode(MeterMode.shutterPriority);
    c.setIso(iso('100'));
    c.setShutter(sh('1/125'));
    expect(c.apertures[c.solvedAperture!.index].label, '16');
    expect(c.solvedShutter, isNull);
  });

  test('manual mode exposes offset', () async {
    await run();
    c.setMode(MeterMode.manual);
    c.setIso(iso('100'));
    c.setAperture(ap('16'));
    c.setShutter(sh('1/60'));
    expect(c.offset, closeTo(1.0, 1e-9));
    expect(c.solvedShutter, isNull);
    expect(c.solvedAperture, isNull);
  });

  test('shutter priority 1/30 at 50 mm warns, 1/60 does not', () async {
    await run();
    c.shakeWarning = true;
    c.setMode(MeterMode.shutterPriority);
    c.setShutter(sh('1/30'));
    expect(c.shakeRiskNow, isTrue);
    c.setShutter(sh('1/60'));
    expect(c.shakeRiskNow, isFalse);
  });

  test('manual mode uses the dialled shutter', () async {
    await run();
    c.shakeWarning = true;
    c.setMode(MeterMode.manual);
    c.setShutter(sh('1/30'));
    expect(c.shakeRiskNow, isTrue);
  });

  test('the setter notifies only on a change', () {
    var n = 0;
    c.addListener(() => n++);
    c.shakeWarning = true;
    c.shakeWarning = true;
    expect(n, 1);
  });

  test('warning off never warns', () async {
    await run();
    c.setMode(MeterMode.shutterPriority);
    c.setShutter(sh('1/30'));
    expect(c.shakeWarning, isFalse);
    expect(c.shakeRiskNow, isFalse);
  });

  test('Bulb warns, no reading does not', () async {
    await c.resume();
    c.shakeWarning = true;
    expect(c.shakeRiskNow, isFalse); // before any stats
    src.emit(stats(exposureNs: 1000000000));
    await settle(); // EV100 0
    c.setIso(iso('100'));
    c.setAperture(ap('22'));
    expect(c.bulbSeconds, isNotNull);
    expect(c.shakeRiskNow, isTrue);
  });

  test('calibration setter re-derives the reading', () async {
    await run();
    c.calibrationEv = 1;
    expect(c.reading!.ev100, closeTo(16, 1e-3));
  });

  test('pause stops the source and resume restarts it', () async {
    await c.resume();
    await c.resume(); // no-op while running
    await c.pause();
    await c.resume();
    expect(src.calls.where((e) => e != 'setRegions'), [
      'start',
      'stop',
      'start',
    ]);
  });

  test('pause while start is in flight releases the camera', () async {
    src.startGate = Completer<void>();
    final starting = c.resume();
    await c.pause();
    src.startGate!.complete();
    await starting;
    expect(src.calls, ['start', 'stop']);
    expect(src.hasListener, isFalse);
    expect(c.preview, isNull);
    await c.resume(); // can start again afterwards
    expect(src.hasListener, isTrue);
  });

  test('resume during an in-flight start keeps the camera', () async {
    src.startGate = Completer<void>();
    final first = c.resume();
    await c.pause();
    final second = c.resume();
    src.startGate!.complete();
    await Future.wait([first, second]);
    expect(src.calls.where((e) => e != 'setRegions'), ['start']);
    expect(src.hasListener, isTrue);
    expect(c.preview, isNotNull);
  });

  test('resume then pause during an in-flight start ends stopped', () async {
    src.startGate = Completer<void>();
    final first = c.resume();
    await c.pause();
    final second = c.resume();
    await c.pause();
    src.startGate!.complete();
    await Future.wait([first, second]);
    expect(src.calls, ['start', 'stop']);
    expect(src.hasListener, isFalse);
  });

  test('dispose while start is in flight releases the camera', () async {
    src.startGate = Completer<void>();
    final starting = c.resume();
    c.dispose();
    src.startGate!.complete();
    await starting;
    expect(src.calls, ['start', 'stop']);
    expect(src.hasListener, isFalse);
    c = MeterController(source: src); // for tearDown
  });

  test('stats received while paused are ignored', () async {
    await run();
    final before = c.reading;
    await c.pause();
    expect(src.hasListener, isFalse);
    src.emit(stats(region: .5));
    await settle();
    expect(c.reading, same(before));
  });

  test('sends regions after start and when focal changes', () async {
    await c.resume();
    expect(src.regions, hasLength(1));
    final first = src.regions.last.$1;
    c.setFocal(focalStops.indexOf(100));
    expect(src.regions, hasLength(2));
    expect(src.regions.last.$1.width, lessThan(first.width));
  });

  test(
    'tapSpot switches to spot and sends regions; clearSpot reverts',
    () async {
      await c.resume();
      c.tapSpot(const Offset(.2, .7));
      expect(c.area, MeterArea.spot);
      expect(c.spot, const Offset(.2, .7));
      expect(src.regions.last.$2, const Offset(.2, .7));
      expect(src.regions.last.$3, .02);
      expect(c.spotRadius, .02);
      c.clearSpot();
      expect(c.area, MeterArea.average);
      expect(c.spot, const Offset(.5, .5));
    },
  );

  test('useSpot meters at the centre first, then at the last spot', () async {
    await c.resume();
    c.useSpot();
    expect(c.area, MeterArea.spot);
    expect(c.spot, const Offset(.5, .5));
    c.tapSpot(const Offset(.45, .55));
    c.clearSpot();
    c.useSpot();
    expect(c.spot, const Offset(.45, .55));
    expect(src.regions.last.$2, const Offset(.45, .55));
  });

  test('held reading ignores new stats until released', () async {
    await run();
    final frozen = c.reading!.ev100;
    c.toggleHold();
    src.emit(stats(exposureNs: 61036)); // one stop darker scene
    await settle();
    expect(c.reading!.ev100, frozen);
    c.toggleHold();
    expect(c.reading!.ev100, closeTo(frozen - 1, 1e-3));
  });

  test(
    'camera permission denied sets cameraDenied and does not throw',
    () async {
      src.startError = PlatformException(code: 'denied');
      await c.resume();
      expect(c.cameraDenied, isTrue);
      expect(c.cameraError, isNull);
      // Dials still work.
      c.setAperture(0);
      expect(c.apertureIndex, 0);
    },
  );

  test('other camera errors are stored, not thrown', () async {
    src.startError = PlatformException(code: 'camera_error', message: 'boom');
    await c.resume();
    expect(c.cameraDenied, isFalse);
    expect(c.cameraError, 'boom');
  });

  test('frames that give no finite EV are skipped', () async {
    await run();
    c.setMode(MeterMode.manual);
    final before = c.reading;
    src.emit(stats(aperture: 0));
    src.emit(stats(exposureNs: 0));
    src.emit(stats(region: double.nan));
    await settle();
    expect(c.reading, same(before));
    expect(c.offset, isNotNull);
    expect(c.offset!.isFinite, isTrue);
    // Switching area re-derives from the last valid frame.
    c.tapSpot(const Offset(.3, .3));
    expect(c.reading!.ev100, closeTo(15, 1e-3));
  });

  test('resume while the cancelled start is still stopping restarts', () async {
    src.startGate = Completer<void>();
    src.stopGate = Completer<void>();
    final first = c.resume();
    await c.pause();
    src.startGate!.complete();
    await settle(); // start resolved; the cancel-path stop is pending
    expect(src.calls, ['start', 'stop']);
    final second = c.resume();
    src.stopGate!.complete();
    await Future.wait([first, second]);
    expect(src.calls.where((e) => e != 'setRegions'), [
      'start',
      'stop',
      'start',
    ]);
    expect(src.hasListener, isTrue);
    expect(c.preview, isNotNull);
  });

  test('stats stream error stops metering and is reported', () async {
    await run();
    expect(c.reading, isNotNull);
    var notified = 0;
    c.addListener(() => notified++);
    src.fail(PlatformException(code: 'camera_error', message: 'disconnected'));
    await settle();
    expect(c.cameraError, 'disconnected');
    expect(c.preview, isNull);
    expect(c.reading, isNull);
    expect(src.hasListener, isFalse);
    expect(notified, greaterThan(0));
    // A later resume recovers.
    await c.resume();
    expect(c.cameraError, isNull);
    expect(c.preview, isNotNull);
    expect(src.hasListener, isTrue);
    src.emit(stats());
    await settle();
    expect(c.reading!.ev100, closeTo(15, 1e-3));
  });

  test('stats stream error keeps a held reading', () async {
    await run();
    c.toggleHold();
    final held = c.reading;
    src.fail(StateError('gone'));
    await settle();
    expect(c.cameraError, isNotNull);
    expect(c.reading, same(held));
  });

  test('held reading derives from the frozen frame, not newer stats', () async {
    await run();
    final frozen = c.reading!.ev100;
    c.toggleHold();
    src.emit(stats(exposureNs: 15259)); // one stop brighter scene
    await settle();
    c.tapSpot(const Offset(.3, .6));
    expect(c.reading!.ev100, closeTo(frozen, 1e-9));
    c.clearSpot();
    expect(c.reading!.ev100, closeTo(frozen, 1e-9));
    c.calibrationEv = 1;
    expect(c.reading!.ev100, closeTo(frozen + 1, 1e-9));
    c.toggleHold(); // released: the newest frame
    expect(c.reading!.ev100, closeTo(frozen + 2, 1e-3));
  });

  group('histogram', () {
    late MeterController h;
    final bins = List<int>.filled(64, 0)..[30] = 10;
    setUp(() async {
      h = MeterController(source: src, histogramOn: true, viewfinderOn: true);
      await h.resume();
    });
    tearDown(() => h.dispose());

    test('starts with the negative latitude and no view', () {
      expect(h.latitude, FilmLatitude.negative);
      expect(h.histogram.value, isNull);
    });

    test('the histogram marks the metered luma', () async {
      src.emit(stats(region: .18, histogram: bins));
      await settle();
      expect(h.histogram.value!.marker, closeTo(.4615, 1e-3));
      h.setLatitude(FilmLatitude.slide);
      expect(h.latitude, FilmLatitude.slide);
      expect(h.histogram.value!.bandEnd, closeTo(.5414, 1e-3));
    });

    test('setLatitude to the same latitude does not notify', () async {
      var n = 0;
      h.addListener(() => n++);
      h.setLatitude(FilmLatitude.negative);
      expect(n, 0);
      h.setLatitude(FilmLatitude.slide);
      expect(n, 1);
    });

    test('a held reading freezes the histogram', () async {
      src.emit(stats(region: .18, histogram: bins));
      await settle();
      h.toggleHold();
      src.emit(stats(region: .72, histogram: bins));
      await settle();
      expect(h.histogram.value!.marker, closeTo(.4615, 1e-3));
      h.toggleHold();
      src.emit(stats(region: .72, histogram: bins));
      await settle();
      expect(h.histogram.value!.marker, closeTo(histogramX(.72), 1e-9));
    });

    test(
      'hidden viewfinder computes nothing, showing it restores the view',
      () async {
        src.emit(stats(region: .18, histogram: bins));
        await settle();
        h.toggleViewfinder();
        expect(h.histogram.value, isNull);
        src.emit(stats(region: .18, histogram: bins));
        await settle();
        expect(h.histogram.value, isNull);
        h.toggleViewfinder();
        expect(h.histogram.value, isNotNull);
      },
    );

    test('manual offset shifts the band', () async {
      src.emit(stats(region: .18, histogram: bins));
      await settle();
      h.setMode(MeterMode.manual);
      h.setIso(h.isos.indexWhere((v) => v.label == '100'));
      h.setAperture(h.apertures.indexWhere((v) => v.label == '8'));
      h.setShutter(h.shutters.indexWhere((v) => v.label == '1/250'));
      expect(h.offset, 1.0);
      expect(h.histogram.value!.bandStart, closeTo(.1634, 1e-3));
    });

    test('the spot meters the spot luma', () async {
      src.emit(
        MeterStats.fromMap({
          'exposureNs': 30518,
          'sensitivity': 100,
          'boost': 100,
          'aperture': 1.0,
          'minExposureNs': 10000,
          'maxExposureNs': 1000000000,
          'minIso': 50,
          'maxIso': 3200,
          'frameLuma': .18,
          'cropLuma': .18,
          'spotLuma': .72,
          'histogram': bins,
        }),
      );
      await settle();
      expect(h.histogram.value!.marker, closeTo(histogramX(.18), 1e-9));
      h.tapSpot(const Offset(.3, .3));
      expect(h.histogram.value!.marker, closeTo(histogramX(.72), 1e-9));
      h.clearSpot();
      expect(h.histogram.value!.marker, closeTo(histogramX(.18), 1e-9));
    });

    test('histogram off publishes null', () async {
      h.toggleHistogram();
      expect(h.histogramOn, isFalse);
      src.emit(stats(region: .18, histogram: bins));
      await settle();
      expect(h.histogram.value, isNull);
      var n = 0;
      h.addListener(() => n++);
      h.toggleHistogram();
      expect(n, 1);
      expect(h.histogramOn, isTrue);
      expect(h.histogram.value, isNotNull);
    });

    test('defaults off', () {
      final d = MeterController(source: src);
      addTearDown(d.dispose);
      expect(d.histogramOn, isFalse);
    });
  });
}
