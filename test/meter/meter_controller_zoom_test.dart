import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/metering/fov.dart';
import 'package:grain/metering/reading.dart';

import '../support/fake_source.dart';

Future<void> settle() => pumpEventQueue();

int idx(List<ScaleValue> s, String label) {
  final i = s.indexWhere((v) => v.label == label);
  if (i < 0) throw StateError('no $label in ${s.map((v) => v.label)}');
  return i;
}

MeterStats stats({double aperture = 1.0, int exposureNs = 1000000000 ~/ 60}) =>
    MeterStats.fromMap({
      'exposureNs': exposureNs,
      'sensitivity': 800,
      'boost': 100,
      'aperture': aperture,
      'minExposureNs': 10000,
      'maxExposureNs': 1000000000,
      'minIso': 50,
      'maxIso': 3200,
      'frameLuma': .18,
      'cropLuma': .09,
      'spotLuma': .18,
      'histogram': List<int>.filled(64, 0),
      'zoom': 4.0,
      'camera': 'tele',
      'aeState': 'converged',
    });

void main() {
  late FakeMeterSource src;
  late MeterController c;

  MeterController make({double maxZoom = 20}) {
    src = FakeMeterSource(
      size: const Size(1440, 1080),
      mainEqFocal: 25,
      wideEqFocal: 13,
      maxZoom: maxZoom,
    );
    return c = MeterController(source: src, statsLog: (_, {wrapWidth}) {});
  }

  tearDown(() {
    c.dispose();
  });

  List<String> zooms() =>
      src.calls.where((e) => e.startsWith('setZoom')).toList();

  /// The whole frame is in the picture, and takes most of it.
  void expectFrameFills() {
    final crop = c.cropRect!;
    expect(c.lensWiderThanCamera, isFalse);
    final larger = math.max(crop.width, crop.height);
    expect(larger, lessThanOrEqualTo(.95 + 1e-9));
    expect(larger, greaterThan(.9));
  }

  test('50 mm gives no camera zoom', () async {
    make();
    await c.resume();
    c.setFocal(idx(c.focalValues, '50'));
    await settle();
    expect(zooms(), isEmpty);
    expect(c.preview!.zoom, 1);
  });

  for (final focal in ['200', '400']) {
    test('$focal mm zooms the camera in with the frame fitting', () async {
      make();
      await c.resume();
      c.setFocal(idx(c.focalValues, focal));
      await settle();
      expect(zooms(), hasLength(1));
      final p = c.preview!;
      expect(p.zoom, greaterThan(2));
      expect(p.phoneEqFocal, closeTo(25 * p.zoom, 1e-9));
      expect(
        lensFits(
          preview: c.previewSize!,
          lensFocal: double.parse(focal),
          phoneEqFocal: p.phoneEqFocal,
        ),
        isTrue,
      );
      expectFrameFills();
      // Regions follow the zoomed picture.
      expect(src.regions.last.$1, c.cropRect);
    });
  }

  test('a sideways frame zooms less than an upright one', () async {
    make();
    await c.resume();
    c.setFocal(idx(c.focalValues, '200'));
    await settle();
    final upright = c.preview!.zoom;
    c.toggleFrameOrientation();
    await settle();
    expect(c.preview!.zoom, lessThan(upright));
    expectFrameFills();
  });

  test('the device maximum caps the zoom', () async {
    make(maxZoom: 10);
    await c.resume();
    c.setFocal(idx(c.focalValues, '400'));
    await settle();
    expect(zooms(), ['setZoom(10.00)']);
    expect(c.preview!.zoom, 10);
    expect(c.preview!.phoneEqFocal, 250);
    expect(c.lensWiderThanCamera, isFalse);
  });

  test('no zoom headroom: no camera zoom', () async {
    make(maxZoom: 1);
    await c.resume();
    c.setFocal(idx(c.focalValues, '600'));
    await settle();
    expect(zooms(), isEmpty);
    expect(c.preview!.zoom, 1);
  });

  test('too little headroom to reach 2×: no camera zoom', () async {
    make(maxZoom: 1.8);
    await c.resume();
    c.setFocal(idx(c.focalValues, '400'));
    await settle();
    expect(zooms(), isEmpty);
  });

  test('dialling back to a normal lens zooms out again', () async {
    make();
    await c.resume();
    c.setFocal(idx(c.focalValues, '200'));
    await settle();
    c.setFocal(idx(c.focalValues, '50'));
    await settle();
    expect(zooms().last, 'setZoom(1.00)');
    expect(c.preview!.zoom, 1);
    expect(c.preview!.phoneEqFocal, 25);
  });

  test('from tele straight to the ultra-wide', () async {
    make();
    await c.resume();
    c.setFocal(idx(c.focalValues, '200'));
    await settle();
    c.setFocal(idx(c.focalValues, '20'));
    await settle();
    expect(zooms().last, 'setZoom(0.52)');
    expect(c.preview!.wide, isTrue);
  });

  test('the zoom is re-applied after pause and resume', () async {
    make();
    c.setFocal(idx(c.focalValues, '400'));
    await c.resume();
    await settle();
    final first = c.preview!.zoom;
    expect(first, greaterThan(2));
    await c.pause();
    await c.resume();
    await settle();
    final last = src.calls.lastIndexOf('start');
    expect(src.calls.sublist(last).where((e) => e.startsWith('setZoom')), [
      zooms().first,
    ]);
    expect(c.preview!.zoom, first);
    expectFrameFills();
  });

  test('the last of quick focal changes wins', () async {
    make();
    await c.resume();
    src.zoomGate = Completer<void>();
    c.setFocal(idx(c.focalValues, '200')); // in flight
    c.setFocal(idx(c.focalValues, '300'));
    c.setFocal(idx(c.focalValues, '400'));
    await settle();
    expect(zooms(), hasLength(1)); // one in flight at a time
    // The frame holds for the old picture until the camera answers.
    expect(c.preview!.zoom, 1);
    src.zoomGate!.complete();
    await settle();
    expect(zooms(), hasLength(2));
    final want = wantedZoomAt400(c.previewSize!);
    expect(c.preview!.zoom, closeTo(want, .01));
    expectFrameFills();
  });

  test('the frame holds until the zoom answers', () async {
    make();
    await c.resume();
    final before = c.cropRect;
    src.zoomGate = Completer<void>();
    c.setFocal(idx(c.focalValues, '200'));
    await settle();
    expect(c.cropRect, before);
    src.zoomGate!.complete();
    await settle();
    expect(c.cropRect, isNot(before));
    expectFrameFills();
  });

  group('stats log', () {
    test('at most once a second, with the EV and the AE data', () async {
      final lines = <String>[];
      var now = DateTime(2026);
      src = FakeMeterSource(size: const Size(1440, 1080));
      c = MeterController(
        source: src,
        statsLog: (m, {wrapWidth}) => lines.add(m!),
        clock: () => now,
      );
      await c.resume();
      src.emit(stats());
      await settle();
      now = now.add(const Duration(milliseconds: 500));
      src.emit(stats());
      await settle();
      expect(lines, hasLength(1));
      now = now.add(const Duration(milliseconds: 600));
      src.emit(stats());
      await settle();
      expect(lines, hasLength(2));
      final line = lines.first;
      expect(line, startsWith('GRAIN stats '));
      for (final part in [
        'iso=800',
        'boost=100',
        'f/1.00',
        'zoom=4.00',
        'cam=tele',
        'ae=converged',
        'frame=0.1800',
        'crop=0.0900',
        'spot=0.1800',
        'ev100=${c.reading!.ev100.toStringAsFixed(2)}',
        'range=ok',
      ]) {
        expect(line, contains(part));
      }
    });

    test('names the AE limits reached', () {
      make(); // for the tearDown
      final s = stats(exposureNs: 1000000000);
      expect(statsLine(s, null), contains('limits=tMax'));
      expect(statsLine(s, null), contains('ev100=-'));
    });
  });
}

/// The zoom wanted for 400 mm upright on the test's 25 mm, 1080×1440
/// camera: 95 % of the fit, floored to hundredths.
double wantedZoomAt400(Size preview) {
  final crop = lensCrop(preview: preview, lensFocal: 400, phoneEqFocal: 25);
  final fit = .95 / math.max(crop.width, crop.height);
  return (math.min(fit, 20) * 100).floorToDouble() / 100;
}
