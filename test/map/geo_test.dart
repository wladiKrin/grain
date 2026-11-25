import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/map/geo.dart';

const _munich = GeoPoint(48.137, 11.575);
const _berlin = GeoPoint(52.52, 13.405);

/// Where [p] lands on a [w] × [h] map looking at [c], in logical pixels.
(double, double) _screen(GeoPoint p, CameraView c, double w, double h) {
  final scale = mapTileSize * math.pow(2, c.zoom);
  final (px, py) = mercator(p);
  final (cx, cy) = mercator(c.center);
  return (w / 2 + (px - cx) * scale, h / 2 + (py - cy) * scale);
}

void main() {
  test('Web Mercator: the equator and date line, the edges, and back', () {
    expect(mercator(const GeoPoint(0, 0)), (.5, .5));
    expect(mercator(const GeoPoint(0, -180)).$1, 0);
    expect(mercator(const GeoPoint(maxLatitude, 0)).$2, closeTo(0, 1e-9));
    expect(mercator(const GeoPoint(-90, 0)).$2, closeTo(1, 1e-9));
    for (final p in const [_munich, _berlin, GeoPoint(-33.9, 151.2)]) {
      final (x, y) = mercator(p);
      final back = fromMercator(x, y);
      expect(back.latitude, closeTo(p.latitude, 1e-9));
      expect(back.longitude, closeTo(p.longitude, 1e-9));
    }
  });

  group('fitCamera', () {
    test('a single spot gives a finite zoom, whatever the map size', () {
      for (final (w, h) in [(392.7, 760.0), (800.0, 1200.0), (100.0, 100.0)]) {
        final c = fitCamera([_munich], width: w, height: h);
        expect(c.zoom.isFinite, isTrue);
        expect(c.zoom, lessThanOrEqualTo(13));
        expect(c.center.longitude, closeTo(_munich.longitude, 1e-6));
      }
      // A phone-sized map is zoomed in to the cap.
      expect(fitCamera([_munich], width: 392.7, height: 760).zoom, 13);
      // Several frames at one spot are one spot.
      expect(
        fitCamera([_munich, _munich, _munich], width: 392.7, height: 760),
        fitCamera([_munich], width: 392.7, height: 760),
      );
    });

    test('several spots are all in view, clear of the margins and above '
        'the card', () {
      const w = 392.7, h = 700.0;
      final c = fitCamera([_munich, _berlin], width: w, height: h);
      expect(c.zoom, lessThan(13));
      for (final p in [_munich, _berlin]) {
        final (x, y) = _screen(p, c, w, h);
        expect(x, inInclusiveRange(48 - 1e-6, w - 48 + 1e-6));
        expect(y, inInclusiveRange(48 - 1e-6, h - 160 + 1e-6));
      }
      // Tight: one of them touches the margin it is fitted to.
      final ys = [
        for (final p in [_munich, _berlin]) _screen(p, c, w, h).$2,
      ];
      expect(ys.reduce(math.min), closeTo(48, 1e-6));
      expect(ys.reduce(math.max), closeTo(h - 160, 1e-6));
    });

    test('nothing to show is the world', () {
      expect(fitCamera([], width: 400, height: 800).zoom, lessThan(3));
    });
  });

  test('screen distance grows with the zoom and goes round the date line', () {
    const a = GeoPoint(0, 0), b = GeoPoint(0, .001);
    final d10 = screenDistance(a, b, 10);
    expect(screenDistance(a, b, 11), closeTo(2 * d10, 1e-9));
    // .001° of longitude at zoom 10 is 512 × 1024 / 360000 pixels.
    expect(d10, closeTo(512 * 1024 / 360000, 1e-9));
    expect(
      screenDistance(
        const GeoPoint(0, 179.9995),
        const GeoPoint(0, -179.9995),
        10,
      ),
      closeTo(d10, 1e-6),
    );
    expect(screenDistance(_munich, _munich, 18), 0);
  });
}
