import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/theme.dart';
import '../version.dart';
import 'basemap.dart';
import 'basemap_geometry.dart';

/// The bundled basemap (see `tool/basemap/`).
const basemapAsset = 'assets/map/basemap.bin';

Future<Basemap>? _bundled;

final _geometries = Expando<BasemapGeometry>('basemap geometry');

/// [map] projected for drawing: built with it by [loadBasemap], otherwise
/// (a basemap from elsewhere, as in tests) built here, once.
BasemapGeometry basemapGeometry(Basemap map) =>
    _geometries[map] ??= BasemapGeometry.build(map);

/// Reads and decodes the basemap from [bundle]; from the app's own bundle
/// it is read once per run, on first opening the map.
Future<Basemap> loadBasemap([AssetBundle? bundle]) {
  Future<Basemap> load(AssetBundle b) async {
    final data = await b.load(basemapAsset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    // About 100k points: decoded, projected and cut into levels of detail
    // off the UI thread (the result is handed back without a copy).
    final (map, geometry) = await Isolate.run(() {
      final m = Basemap.decode(bytes);
      return (m, BasemapGeometry.build(m));
    });
    _geometries[map] = geometry;
    return map;
  }

  if (bundle != null) return load(bundle);
  return _bundled ??= load(rootBundle).catchError((Object e) {
    _bundled = null;
    throw e;
  });
}

/// Where the online tiles come from: OpenStreetMap's own servers, used as
/// their tile usage policy asks (an identifying User-Agent, visible
/// attribution, no prefetching).
const osmUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Names Grain and where it lives, as the OSM tile policy asks.
const osmUserAgent = 'Grain/$appVersion (+https://github.com/wladiKrin/grain)';

const osmAttribution = '© OpenStreetMap contributors';

/// A tile provider for [osmUrlTemplate]: a modest disk cache in the app's
/// cache directory, and failures (no network, network permission revoked)
/// shown as empty tiles over the offline layers, never as errors.
TileProvider osmTileProvider() => NetworkTileProvider(
  headers: {'User-Agent': osmUserAgent},
  silenceExceptions: true,
  cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: 50 * 1024 * 1024,
  ),
);

/// Water and the other basemap colours, from the Grain palette: the paper
/// ground as land on a slate sea in light mode, warm grey land on a near
/// black sea in dark mode.
class MapColors {
  const MapColors({
    required this.water,
    required this.land,
    required this.coast,
    required this.border,
    required this.label,
    required this.capital,
  });

  factory MapColors.of(GrainPalette g, Brightness b) => b == Brightness.dark
      ? MapColors(
          water: const Color(0xFF0E1417),
          land: const Color(0xFF302D29),
          coast: const Color(0xFF5A554E),
          border: const Color(0xFF6E685F).withValues(alpha: .6),
          label: g.secondary,
          capital: g.ink,
        )
      : MapColors(
          water: const Color(0xFFC5D0D2),
          land: g.ground,
          coast: const Color(0xFF9A9286),
          border: const Color(0xFF8F887C).withValues(alpha: .7),
          label: g.secondary,
          capital: g.ink,
        );

  final Color water, land, coast, border, label, capital;

  @override
  bool operator ==(Object other) =>
      other is MapColors &&
      other.water == water &&
      other.land == land &&
      other.coast == coast &&
      other.border == border &&
      other.label == label &&
      other.capital == capital;

  @override
  int get hashCode => Object.hash(water, land, coast, border, label, capital);
}

/// The basemap layers, bottom to top: land, lakes, shores and borders in
/// one layer, then the place names.
List<Widget> basemapLayers(Basemap map, MapColors colors) {
  final geometry = basemapGeometry(map);
  return [
    BasemapLayer(geometry: geometry, colors: colors),
    PlaceLabels(places: map.places, geometry: geometry, colors: colors),
  ];
}

/// Land, lakes, shores and borders, drawn from paths built once per cell:
/// a frame only moves and scales the canvas to the camera.
class BasemapLayer extends StatelessWidget {
  const BasemapLayer({super.key, required this.geometry, required this.colors});

  final BasemapGeometry geometry;
  final MapColors colors;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: BasemapPainter(camera, geometry, colors),
        ),
      ),
    );
  }
}

/// A cell's paths, built the first time it is on screen.
class _CellPaths {
  _CellPaths(BasemapCell c)
    : land = _path(c.land, close: true),
      lakes = _path(c.lakes, close: true),
      coast = _path(c.coast, close: false),
      borders = _path(c.borders, close: false);

  final ui.Path? land, lakes, coast, borders;

  static ui.Path? _path(Rings r, {required bool close}) {
    if (r.count == 0) return null;
    BasemapPainter.pathBuilds++;
    final p = ui.Path()..fillType = ui.PathFillType.evenOdd;
    final xy = r.xy, starts = r.starts;
    for (var k = 0; k < r.count; k++) {
      final a = starts[k], b = starts[k + 1];
      p.moveTo(xy[2 * a], xy[2 * a + 1]);
      for (var i = a + 1; i < b; i++) {
        p.lineTo(xy[2 * i], xy[2 * i + 1]);
      }
      if (close) p.close();
    }
    return p;
  }
}

final _cellPaths = Expando<_CellPaths>('basemap cell paths');

/// Draws a [BasemapGeometry] level for [camera]: per cell on screen, a
/// translate, a scale and its paths; no point is touched.
class BasemapPainter extends CustomPainter {
  BasemapPainter(this.camera, this.geometry, this.colors);

  final MapCamera camera;
  final BasemapGeometry geometry;
  final MapColors colors;

  /// Paths built so far, over all basemaps: each cell's once.
  @visibleForTesting
  static int pathBuilds = 0;

  /// Line widths on screen, in logical pixels.
  static const coastWidth = 1.0, borderWidth = .8;

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = camera.zoom;
    if (!zoom.isFinite) return;
    final s = math.pow(2, zoom).toDouble();
    final o = camera.pixelOrigin;
    final level = geometry.levelFor(zoom);
    // The visible world, and the copies of it east and west that show.
    final l = o.dx / s, t = o.dy / s;
    final r = (o.dx + size.width) / s, b = (o.dy + size.height) / s;
    final k0 = (l / worldSize).floor();
    final k1 = math.min((r / worldSize).floor(), k0 + 3);
    final visible = <(BasemapCell, double)>[];
    for (var k = k0; k <= k1; k++) {
      final dx = k * worldSize;
      for (final c in level.cells) {
        if (c.overlaps(l - dx, t, r - dx, b)) visible.add((c, dx));
      }
    }
    if (visible.isEmpty) return;

    // A level in one cell has anti-aliased fills. Cut into cells, it has
    // not, so no seam shows where cells meet (the shore is drawn over the
    // edge of the land anyway).
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = level.cells.length == 1;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.bevel
      ..strokeCap = StrokeCap.round;

    void pass(ui.Path? Function(_CellPaths p) pick, Paint paint) {
      for (final (c, dx) in visible) {
        final path = pick(_cellPaths[c] ??= _CellPaths(c));
        if (path == null) continue;
        canvas
          ..save()
          ..translate((c.anchorX + dx) * s - o.dx, c.anchorY * s - o.dy)
          ..scale(s)
          ..drawPath(path, paint)
          ..restore();
      }
    }

    pass((p) => p.land, fill..color = colors.land);
    pass((p) => p.lakes, fill..color = colors.water);
    pass(
      (p) => p.coast,
      stroke
        ..color = colors.coast
        ..strokeWidth = coastWidth / s,
    );
    pass(
      (p) => p.borders,
      stroke
        ..color = colors.border
        ..strokeWidth = borderWidth / s,
    );
  }

  @override
  bool shouldRepaint(BasemapPainter old) =>
      old.camera != camera || old.geometry != geometry || old.colors != colors;
}

/// Place names for the camera's zoom, the most prominent first, leaving
/// out any that would overlap one already drawn.
class PlaceLabels extends StatefulWidget {
  const PlaceLabels({
    super.key,
    required this.places,
    required this.geometry,
    required this.colors,
  });

  final List<Place> places;

  /// For the places' world positions.
  final BasemapGeometry geometry;
  final MapColors colors;

  /// Labels drawn at most, so a world view stays quick.
  static const maxLabels = 80;

  @override
  State<PlaceLabels> createState() => _PlaceLabelsState();
}

class _PlaceLabelsState extends State<PlaceLabels> {
  final _cache = LabelCache();

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _LabelPainter(camera, widget, _cache),
        ),
      ),
    );
  }
}

/// Laid-out place names, kept across frames: a pan or zoom only paints
/// them. Past [capacity], the least recently drawn go; all go when the
/// colours change.
class LabelCache {
  LabelCache({this.capacity = 400});

  final int capacity;
  final _painters = <int, TextPainter>{};
  MapColors? _colors;

  /// Labels laid out so far.
  @visibleForTesting
  int layouts = 0;

  /// Labels laid out so far by every cache.
  @visibleForTesting
  static int totalLayouts = 0;

  int get length => _painters.length;

  /// The label of place [index], laid out once.
  TextPainter painter(int index, Place p, MapColors colors) {
    if (colors != _colors) {
      _clear();
      _colors = colors;
    }
    final hit = _painters.remove(index);
    if (hit != null) return _painters[index] = hit;
    layouts++;
    totalLayouts++;
    final text = TextPainter(
      text: TextSpan(
        text: p.name,
        style: TextStyle(
          fontFamily: grainFont,
          fontSize: p.capital ? 12 : 11,
          fontWeight: p.capital ? FontWeight.w600 : FontWeight.w400,
          color: p.capital ? colors.capital : colors.label,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (_painters.length >= capacity) {
      _painters.remove(_painters.keys.first)?.dispose();
    }
    return _painters[index] = text;
  }

  void _clear() {
    for (final t in _painters.values) {
      t.dispose();
    }
    _painters.clear();
  }

  void dispose() => _clear();
}

class _LabelPainter extends CustomPainter {
  _LabelPainter(this.camera, this.labels, this.cache);

  final MapCamera camera;
  final PlaceLabels labels;
  final LabelCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = camera.zoom;
    if (!zoom.isFinite) return;
    final s = math.pow(2, zoom).toDouble();
    final o = camera.pixelOrigin;
    final colors = labels.colors;
    final places = labels.places;
    final xy = labels.geometry.placeXY;
    final ws = worldSize * s;
    final k0 = (o.dx / ws).floor();
    final k1 = math.min(((o.dx + size.width) / ws).floor(), k0 + 3);
    final screen = Offset.zero & size;
    final taken = <Rect>[];
    final dot = Paint()..color = colors.label;
    final n = math.min(places.length, xy.length ~/ 2);
    for (var i = 0; i < n; i++) {
      if (taken.length >= PlaceLabels.maxLabels) break;
      final p = places[i];
      // Sorted by min zoom: nothing later shows at this zoom either.
      if (p.minZoom > zoom) break;
      final y = xy[2 * i + 1] * s - o.dy;
      if (y < 0 || y > size.height) continue;
      for (var k = k0; k <= k1; k++) {
        final at = Offset(xy[2 * i] * s + k * ws - o.dx, y);
        if (!screen.contains(at)) continue;
        final text = cache.painter(i, p, colors);
        final origin = at + Offset(5, -text.height / 2);
        final rect = (origin & text.size)
            .inflate(3)
            .expandToInclude(Rect.fromCircle(center: at, radius: 3));
        if (taken.any(rect.overlaps)) continue;
        taken.add(rect);
        canvas.drawCircle(at, p.capital ? 2.5 : 2, dot);
        text.paint(canvas, origin);
      }
    }
  }

  @override
  bool shouldRepaint(_LabelPainter old) =>
      old.camera != camera ||
      old.labels.places != labels.places ||
      old.labels.colors != labels.colors ||
      old.cache != cache;
}
