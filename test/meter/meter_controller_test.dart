import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/metering/fov.dart';
import 'package:grain/metering/meter_channel.dart';
import 'package:grain/metering/reading.dart';

class FakeSource implements MeterSource {
  final calls = <String>[];
  final regions = <(Rect, Offset, double)>[];
  final _stats = StreamController<MeterStats>.broadcast();
  Object? startError;
  Completer<void>? startGate;
  Completer<void>? stopGate;

  @override
  Future<PreviewInfo> start() async {
    calls.add('start');
    await startGate?.future;
    if (startError != null) throw startError!;
    return const PreviewInfo(
      textureId: 1,
      size: Size(4000, 3000),
      sensorOrientation: 90,
      phoneEqFocal: 25,
    );
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    await stopGate?.future;
  }

  @override
  Future<void> setRegions(Rect crop, Offset spot, double radius) async {
    calls.add('setRegions');
    regions.add((crop, spot, radius));
  }

  @override
  Stream<MeterStats> get stats => _stats.stream;

  bool get hasListener => _stats.hasListener;
  void emit(MeterStats s) => _stats.add(s);
  void fail(Object error) => _stats.addError(error);
}

/// Stats giving EV100 = 15 (f/1, 1/32768 s, ISO 100, region == frame).
MeterStats stats({
  double region = .18,
  int exposureNs = 30518,
  double aperture = 1.0,
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
      'histogram': List<int>.filled(64, 0),
    });

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeSource src;
  late MeterController c;
  setUp(() {
    src = FakeSource();
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
      expect(src.regions.last.$3, .04);
      c.clearSpot();
      expect(c.area, MeterArea.average);
      expect(c.spot, const Offset(.5, .5));
    },
  );

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
}
