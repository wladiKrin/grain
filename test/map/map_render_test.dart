import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/map/basemap.dart';
import 'package:grain/map/basemap_geometry.dart';
import 'package:grain/map/map_layers.dart';
import 'package:grain/map/map_screen.dart';
import 'package:grain/ui/theme.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG relative luminance contrast of [a] and [b] (1 to 21).
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// A colour [c] drawn at its alpha over [under].
Color over(Color c, Color under) => Color.alphaBlend(c, under);

const _square = Basemap(
  land: [
    MapPolygon([LatLng(40, 0), LatLng(60, 0), LatLng(60, 20), LatLng(40, 20)]),
  ],
  lakes: [
    MapPolygon([LatLng(47.5, 9), LatLng(47.7, 9.5), LatLng(47.4, 9.6)]),
  ],
  borders: [
    [LatLng(44, 2), LatLng(44, 18)],
  ],
  places: [Place(name: 'Munich', position: LatLng(48.14, 11.58), minZoom: 1)],
);

/// Shoelace area of the closed rings of [r], offset by the anchor.
double area(Rings r) {
  var sum = 0.0;
  for (var k = 0; k < r.count; k++) {
    final a = r.starts[k], b = r.starts[k + 1];
    var s = 0.0;
    for (var i = a; i < b; i++) {
      final j = i + 1 < b ? i + 1 : a;
      s += r.xy[2 * i] * r.xy[2 * j + 1] - r.xy[2 * j] * r.xy[2 * i + 1];
    }
    sum += s.abs() / 2;
  }
  return sum;
}

void main() {
  for (final b in Brightness.values) {
    group('$b colours', () {
      final g = GrainPalette.of(b);
      final c = MapColors.of(g, b);

      test('land and water are told apart', () {
        expect(contrast(c.land, c.water), greaterThanOrEqualTo(1.3));
      });

      test('shores and borders show on land, labels read', () {
        expect(contrast(c.coast, c.land), greaterThanOrEqualTo(1.6));
        expect(contrast(c.coast, c.water), greaterThanOrEqualTo(1.6));
        expect(
          contrast(over(c.border, c.land), c.land),
          greaterThanOrEqualTo(1.6),
        );
        expect(contrast(c.label, c.land), greaterThanOrEqualTo(4.5));
        expect(contrast(c.capital, c.land), greaterThanOrEqualTo(4.5));
      });

      test('neither is near black in dark mode', () {
        if (b == Brightness.dark) {
          // The near-black land of the first map (#151413) read as a blank
          // screen.
          expect(c.land.computeLuminance(), greaterThan(.02));
        } else {
          expect(c.land, g.ground);
        }
      });
    });
  }

  group('geometry', () {
    test('projects as flutter_map does', () {
      const crs = Epsg3857();
      for (final p in const [
        LatLng(0, 0),
        LatLng(52.52, 13.405),
        LatLng(-33.9, 151.2),
        LatLng(89, -179),
      ]) {
        final o = crs.latLngToOffset(p, 0);
        final (x, y) = worldXY(p.latitude, p.longitude);
        expect(x, closeTo(o.dx, 1e-9));
        expect(y, closeTo(o.dy, 1e-9));
      }
    });

    test('a polygon lands at its world bounds in every level, the area '
        'kept when cut into cells', () {
      final geo = BasemapGeometry.build(_square);
      final (x0, y1) = worldXY(40, 0);
      final (x1, y0) = worldXY(60, 20);
      expect(x0, 128);
      expect(x1, closeTo(128 + 256 * 20 / 360, 1e-9));
      final whole = (x1 - x0) * (y1 - y0);
      for (final level in geo.levels) {
        final land = [
          for (final c in level.cells)
            if (c.land.count > 0) c,
        ];
        final l = land.map((c) => c.left).reduce(math.min);
        final r = land.map((c) => c.right).reduce(math.max);
        final t = land.map((c) => c.top).reduce(math.min);
        final bt = land.map((c) => c.bottom).reduce(math.max);
        expect(l, closeTo(x0, 1e-4));
        expect(r, closeTo(x1, 1e-4));
        expect(t, closeTo(y0, 1e-4));
        expect(bt, closeTo(y1, 1e-4));
        expect(
          land.fold<double>(0, (s, c) => s + area(c.land)),
          closeTo(whole, whole * 1e-5),
        );
      }
      // The detailed level is cut: 20° of longitude spans cells 8 wide.
      expect(geo.levels.last.cells.length, greaterThan(1));
      for (final c in geo.levels.last.cells) {
        expect(c.anchorX % 8, 0);
        expect(c.anchorY % 8, 0);
      }
    });

    test('shores leave out the cuts along the date line and the edge', () {
      const antarctica = Basemap(
        land: [
          MapPolygon([
            LatLng(-70, -180),
            LatLng(-65, 0),
            LatLng(-70, 180),
            LatLng(-90, 180),
            LatLng(-90, -180),
            LatLng(-70, -180),
          ]),
        ],
      );
      final geo = BasemapGeometry.build(antarctica);
      for (final level in geo.levels) {
        for (final c in level.cells) {
          final xy = c.coast.xy;
          for (var i = 0; i < xy.length; i += 2) {
            final y = xy[i + 1] + c.anchorY;
            expect(y, lessThan(255), reason: 'no shore along the bottom');
          }
          for (var k = 0; k < c.coast.count; k++) {
            final a = c.coast.starts[k], e = c.coast.starts[k + 1];
            for (var i = a; i + 1 < e; i++) {
              final xa = xy[2 * i] + c.anchorX, xb = xy[2 * i + 2] + c.anchorX;
              final onDateLine =
                  (xa < 1e-3 && xb < 1e-3) || (xa > 255.99 && xb > 255.99);
              expect(onDateLine, isFalse, reason: 'no shore on the date line');
            }
          }
        }
      }
    });

    test('the coarse levels have fewer points', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final data = await rootBundle.load(basemapAsset);
      final map = Basemap.decode(data.buffer.asUint8List());
      final geo = BasemapGeometry.build(map);
      final points = [for (final l in geo.levels) l.points];
      for (var i = 1; i < points.length; i++) {
        expect(points[i - 1], lessThan(points[i]));
      }
      expect(points.first, lessThan(points.last / 4));
      // The full level keeps every point of the data (plus the cuts).
      final source = [...map.land, ...map.lakes].fold<int>(
        0,
        (n, p) =>
            n + p.outline.length + p.holes.fold(0, (m, h) => m + h.length),
      );
      final full = geo.levels.last;
      expect(
        full.cells.fold<int>(0, (n, c) => n + c.land.length + c.lakes.length),
        greaterThanOrEqualTo(source * .99),
      );
      expect(geo.levelFor(1).minZoom, double.negativeInfinity);
      expect(geo.levelFor(12), same(full));
    });
  });

  group('labels', () {
    const place = Place(
      name: 'Berlin',
      position: LatLng(52.5, 13.4),
      minZoom: 1,
    );
    final light = MapColors.of(GrainPalette.light, Brightness.light);
    final dark = MapColors.of(GrainPalette.dark, Brightness.dark);

    testWidgets('are laid out once per place and colours', (t) async {
      final cache = LabelCache(capacity: 2);
      addTearDown(cache.dispose);
      final a = cache.painter(0, place, light);
      expect(cache.painter(0, place, light), same(a));
      expect(cache.layouts, 1);
      cache.painter(1, place, light);
      cache.painter(0, place, light);
      cache.painter(2, place, light); // Evicts 1, the least recent.
      expect(cache.length, 2);
      expect(cache.painter(0, place, light), same(a));
      expect(cache.layouts, 3);
      cache.painter(0, place, dark);
      expect(cache.layouts, 4);
    });
  });

  group('camera', () {
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(0, 0),
      zoom: 3,
      rotation: 0,
      nonRotatedSize: const Size(392, 800),
      minZoom: 1,
      maxZoom: 19,
    );

    test('a single spot gives a finite zoom, whatever the map size', () {
      const munich = LatLng(48.137, 11.575);
      for (final size in const [Size(392, 800), Size(100, 100), Size.zero]) {
        for (final points in const [
          [munich],
          [munich, munich, munich],
        ]) {
          final fitted = cameraFitFor(points)
              .fit(camera.withNonRotatedSize(size));
          expect(fitted.zoom.isFinite, isTrue, reason: '$size');
          expect(fitted.zoom, inInclusiveRange(1, 13));
          expect(fitted.center.longitude, closeTo(munich.longitude, 1e-6));
        }
      }
      final one = cameraFitFor(const [munich]).fit(camera);
      expect(one.zoom, 13);
    });

    test('several spots fit as before', () {
      final fitted = cameraFitFor(const [
        LatLng(48.137, 11.575),
        LatLng(52.52, 13.405),
      ]).fit(camera);
      expect(fitted.zoom, inExclusiveRange(4, 9));
    });
  });

  group('rendered', () {
    Future<(Color Function(int x, int y), MapController)> render(
      WidgetTester t,
      Brightness b,
      Basemap map, {
      LatLng center = const LatLng(50, 10),
      double zoom = 3,
    }) async {
      t.view.physicalSize = const Size(400, 400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      final controller = MapController();
      addTearDown(controller.dispose);
      final colors = MapColors.of(GrainPalette.of(b), b);
      await t.pumpWidget(
        MaterialApp(
          theme: grainTheme(b),
          home: RepaintBoundary(
            key: key,
            child: FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                backgroundColor: colors.water,
              ),
              children: basemapLayers(map, colors),
            ),
          ),
        ),
      );
      await t.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = (await t.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data;
      }))!;
      Color pixel(int x, int y) {
        final i = (y * 400 + x) * 4;
        return Color.fromARGB(
          bytes.getUint8(i + 3),
          bytes.getUint8(i),
          bytes.getUint8(i + 1),
          bytes.getUint8(i + 2),
        );
      }

      return (pixel, controller);
    }

    void expectNear(Color a, Color b) {
      expect((a.r - b.r).abs(), lessThan(.02), reason: '$a vs $b');
      expect((a.g - b.g).abs(), lessThan(.02), reason: '$a vs $b');
      expect((a.b - b.b).abs(), lessThan(.02), reason: '$a vs $b');
    }

    for (final b in Brightness.values) {
      for (final zoom in [1.5, 3.0, 4.0, 6.0]) {
        testWidgets('$b at zoom $zoom: land and water in their colours', (
          t,
        ) async {
          final c = MapColors.of(GrainPalette.of(b), b);
          // Close in, the view is of the square's south-west corner.
          final (pixel, _) = await render(
            t,
            b,
            _square,
            zoom: zoom,
            center: zoom > 5 ? const LatLng(41, 1) : const LatLng(50, 10),
          );
          final land = pixel(200, 200), water = pixel(2, 2);
          expectNear(land, c.land);
          expectNear(water, c.water);
          expect(contrast(land, water), greaterThanOrEqualTo(1.3));
        });
      }
    }

    testWidgets('across the date line, the copy east of it draws', (t) async {
      const fiji = Basemap(
        land: [
          MapPolygon([
            LatLng(-20, 170),
            LatLng(-10, 170),
            LatLng(-10, 180),
            LatLng(-20, 180),
          ]),
          MapPolygon([
            LatLng(-20, -180),
            LatLng(-10, -180),
            LatLng(-10, -170),
            LatLng(-20, -170),
          ]),
        ],
      );
      final c = MapColors.of(GrainPalette.light, Brightness.light);
      final (pixel, _) = await render(
        t,
        Brightness.light,
        fiji,
        center: const LatLng(-15, 180),
        zoom: 4,
      );
      expectNear(pixel(150, 200), c.land);
      expectNear(pixel(250, 200), c.land);
      expectNear(pixel(200, 20), c.water);
    });

    testWidgets('60 frames of panning build no path and lay out no label', (
      t,
    ) async {
      final map = (await t.runAsync(() => loadBasemap(rootBundle)))!;
      for (final (center, zoom) in const [
        (LatLng(48, 10), 5.5),
        (LatLng(30, 0), 1.5),
        (LatLng(45, 5), 3.8),
      ]) {
        final (_, controller) = await render(
          t,
          Brightness.dark,
          map,
          center: center,
          zoom: zoom,
        );
        // Over and back: the second sweep only sees what the first did.
        Future<void> sweep(double dir) async {
          for (var i = 0; i < 60; i++) {
            final cam = controller.camera;
            controller.move(
              cam.screenOffsetToLatLng(
                cam.size.center(Offset.zero) + Offset(dir * 4, dir * 2),
              ),
              cam.zoom,
            );
            await t.pump(const Duration(milliseconds: 16));
          }
        }

        await sweep(1);
        await sweep(-1);
        final paths = BasemapPainter.pathBuilds;
        final labels = LabelCache.totalLayouts;
        await sweep(1);
        await sweep(-1);
        expect(BasemapPainter.pathBuilds, paths, reason: '$center $zoom');
        expect(LabelCache.totalLayouts, labels, reason: '$center $zoom');
      }
    });
  });
}
