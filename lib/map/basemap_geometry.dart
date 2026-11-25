import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import 'basemap.dart';

/// The basemap projected once, for drawing with a canvas transform only.
///
/// Pure Dart (no Flutter), so it can be built off the UI thread.
///
/// Coordinates are Web Mercator "world" units: flutter_map's EPSG:3857 at
/// zoom 0, [worldSize] across, x east from the date line, y south from the
/// top edge (85.05° N). A point at zoom z is at `world × 2^z` pixels, so a
/// frame only has to translate and scale the canvas: nothing is reprojected.
///
/// The map comes in [levels] of detail: simplified ones for the world and
/// continent views, the full 1:50m one from [BasemapLevel.minZoom] of the
/// last level. The detailed level is cut into a grid of cells, each in
/// coordinates from its own corner, so that only the cells on screen are
/// drawn and 32-bit floats keep sub-pixel precision at street zooms.
class BasemapGeometry {
  BasemapGeometry._(this.levels, this.placeXY);

  /// Projects, simplifies and cuts [map] into [levels].
  factory BasemapGeometry.build(Basemap map) {
    final land = [for (final p in map.land) _project(p)];
    final lakes = [for (final p in map.lakes) _project(p)];
    final borders = [for (final l in map.borders) _line(l)];
    final places = Float64List(map.places.length * 2);
    for (var i = 0; i < map.places.length; i++) {
      final p = map.places[i].position;
      final (x, y) = worldXY(p.latitude, p.longitude);
      places[2 * i] = x;
      places[2 * i + 1] = y;
    }
    return BasemapGeometry._([
      for (final s in levelSpecs) _level(s, land, lakes, borders),
    ], places);
  }

  /// What each level is drawn from (its [LevelSpec.minZoom]), how far it
  /// strays from the data (half a pixel at the zoom it gives way to the
  /// next), and the cells it is cut into across the world.
  static const levelSpecs = [
    LevelSpec(minZoom: double.negativeInfinity, tolerance: .5 / 4, grid: 1),
    LevelSpec(minZoom: 2, tolerance: .5 / 11.3, grid: 1),
    LevelSpec(minZoom: 3.5, tolerance: .5 / 32, grid: 8),
    LevelSpec(minZoom: 5, tolerance: 0, grid: 32),
  ];

  /// Coarsest first.
  final List<BasemapLevel> levels;

  /// Each place's world position: x, y in [Basemap.places] order.
  final Float64List placeXY;

  /// The level to draw at [zoom].
  BasemapLevel levelFor(double zoom) {
    var l = levels.first;
    for (final c in levels) {
      if (zoom >= c.minZoom) l = c;
    }
    return l;
  }
}

/// World units across: 256, a zoom-0 tile.
const worldSize = 256.0;

/// Web Mercator's edge latitude.
const maxLatitude = 85.0511287798;

/// [lat], [lon] in world units, as flutter_map's EPSG:3857 projects them.
(double, double) worldXY(double lat, double lon) {
  final l = lat < -maxLatitude
      ? -maxLatitude
      : (lat > maxLatitude ? maxLatitude : lat);
  final s = math.sin(l * math.pi / 180);
  final y = (.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * worldSize;
  return ((lon + 180) / 360 * worldSize, y);
}

class LevelSpec {
  const LevelSpec({
    required this.minZoom,
    required this.tolerance,
    required this.grid,
  });

  final double minZoom;

  /// Douglas–Peucker tolerance in world units; 0 keeps every point.
  final double tolerance;

  /// Cells per side.
  final int grid;
}

class BasemapLevel {
  BasemapLevel(this.minZoom, this.cells);

  final double minZoom;
  final List<BasemapCell> cells;

  /// Points over all cells and layers.
  int get points => cells.fold(0, (n, c) => n + c.points);
}

/// One cell of a level: its land and lake fills, the shorelines and the
/// borders, in coordinates from ([anchorX], [anchorY]).
class BasemapCell {
  BasemapCell({
    required this.anchorX,
    required this.anchorY,
    required this.land,
    required this.lakes,
    required this.coast,
    required this.borders,
  }) {
    var l = double.infinity, t = double.infinity;
    var r = double.negativeInfinity, b = double.negativeInfinity;
    for (final s in [land, lakes, coast, borders]) {
      final xy = s.xy;
      for (var i = 0; i < xy.length; i += 2) {
        final x = xy[i] + anchorX, y = xy[i + 1] + anchorY;
        if (x < l) l = x;
        if (x > r) r = x;
        if (y < t) t = y;
        if (y > b) b = y;
      }
    }
    left = l;
    top = t;
    right = r;
    bottom = b;
  }

  final double anchorX, anchorY;

  /// Closed rings, filled even-odd (holes are rings too).
  final Rings land, lakes;

  /// Open lines: land and lake outlines (without the cuts along the date
  /// line and the projection's edge), and the country borders.
  final Rings coast, borders;

  /// The world bounds of everything in the cell.
  late final double left, top, right, bottom;

  int get points => land.length + lakes.length + coast.length + borders.length;

  bool overlaps(double l, double t, double r, double b) =>
      left <= r && right >= l && top <= b && bottom >= t;
}

/// Rings or lines: point i is (xy[2i], xy[2i+1]); ring k is points
/// starts[k] until starts[k+1].
class Rings {
  Rings(this.xy, this.starts);

  static final empty = Rings(Float32List(0), Int32List.fromList([0]));

  final Float32List xy;
  final Int32List starts;

  int get length => xy.length ~/ 2;
  int get count => starts.length - 1;
}

/// A polygon in world units: its rings, the outline first.
typedef _Poly = List<Float64List>;

_Poly _project(MapPolygon p) => [
  _line(p.outline),
  for (final h in p.holes) _line(h),
];

Float64List _line(List<LatLng> points) {
  final out = Float64List(points.length * 2);
  for (var i = 0; i < points.length; i++) {
    final (x, y) = worldXY(points[i].latitude, points[i].longitude);
    out[2 * i] = x;
    out[2 * i + 1] = y;
  }
  return out;
}

/// Builds the cells' contents, then the cells.
class _CellBuilder {
  _CellBuilder(this.grid) : size = worldSize / grid;

  final int grid;
  final double size;
  final _land = <int, List<Float64List>>{};
  final _lakes = <int, List<Float64List>>{};
  final _coast = <int, List<Float64List>>{};
  final _borders = <int, List<Float64List>>{};

  int _cellOf(double x, double y) {
    final i = (x / size).floor().clamp(0, grid - 1);
    final j = (y / size).floor().clamp(0, grid - 1);
    return j * grid + i;
  }

  /// Cuts [rings] (one polygon) into the cells it covers.
  void fill(Map<int, List<Float64List>> into, List<Float64List> rings) {
    if (grid == 1) {
      (into[0] ??= []).addAll(rings);
      return;
    }
    final (l, t, r, b) = _bounds(rings);
    _split(
      into,
      rings,
      (l / size).floor().clamp(0, grid - 1),
      (t / size).floor().clamp(0, grid - 1),
      (r / size).floor().clamp(0, grid - 1) + 1,
      (b / size).floor().clamp(0, grid - 1) + 1,
    );
  }

  /// Cells [i0, i1) × [j0, j1): halves the range along its longer side
  /// until one cell is left.
  void _split(
    Map<int, List<Float64List>> into,
    List<Float64List> rings,
    int i0,
    int j0,
    int i1,
    int j1,
  ) {
    if (rings.isEmpty) return;
    if (i1 - i0 == 1 && j1 - j0 == 1) {
      (into[j0 * grid + i0] ??= []).addAll(rings);
      return;
    }
    if (i1 - i0 >= j1 - j0) {
      final m = (i0 + i1) ~/ 2;
      final c = m * size;
      _split(into, _clip(rings, c, 0, false), i0, j0, m, j1);
      _split(into, _clip(rings, c, 0, true), m, j0, i1, j1);
    } else {
      final m = (j0 + j1) ~/ 2;
      final c = m * size;
      _split(into, _clip(rings, c, 1, false), i0, j0, i1, m);
      _split(into, _clip(rings, c, 1, true), i0, m, i1, j1);
    }
  }

  /// Sends each segment of [line] to the cell its start is in.
  void line(Map<int, List<Float64List>> into, Float64List line) {
    final n = line.length ~/ 2;
    if (n < 2) return;
    if (grid == 1) {
      (into[0] ??= []).add(line);
      return;
    }
    var start = 0;
    var cell = _cellOf(line[0], line[1]);
    for (var k = 1; k < n - 1; k++) {
      final c = _cellOf(line[2 * k], line[2 * k + 1]);
      if (c != cell) {
        (into[cell] ??= []).add(
          Float64List.sublistView(line, 2 * start, 2 * k + 2),
        );
        start = k;
        cell = c;
      }
    }
    (into[cell] ??= []).add(Float64List.sublistView(line, 2 * start));
  }

  List<BasemapCell> cells() {
    final keys = {
      ..._land.keys,
      ..._lakes.keys,
      ..._coast.keys,
      ..._borders.keys,
    }.toList()..sort();
    return [
      for (final k in keys)
        () {
          final ax = (k % grid) * size, ay = (k ~/ grid) * size;
          return BasemapCell(
            anchorX: ax,
            anchorY: ay,
            land: _pack(_land[k], ax, ay),
            lakes: _pack(_lakes[k], ax, ay),
            coast: _pack(_coast[k], ax, ay),
            borders: _pack(_borders[k], ax, ay),
          );
        }(),
    ];
  }
}

Rings _pack(List<Float64List>? lines, double ax, double ay) {
  if (lines == null || lines.isEmpty) return Rings.empty;
  final total = lines.fold<int>(0, (n, l) => n + l.length);
  final xy = Float32List(total);
  final starts = Int32List(lines.length + 1);
  var o = 0;
  for (var k = 0; k < lines.length; k++) {
    final l = lines[k];
    starts[k] = o ~/ 2;
    for (var i = 0; i < l.length; i += 2) {
      xy[o++] = l[i] - ax;
      xy[o++] = l[i + 1] - ay;
    }
  }
  starts[lines.length] = o ~/ 2;
  return Rings(xy, starts);
}

(double, double, double, double) _bounds(List<Float64List> rings) {
  var l = double.infinity, t = double.infinity;
  var r = double.negativeInfinity, b = double.negativeInfinity;
  for (final ring in rings) {
    for (var i = 0; i < ring.length; i += 2) {
      final x = ring[i], y = ring[i + 1];
      if (x < l) l = x;
      if (x > r) r = x;
      if (y < t) t = y;
      if (y > b) b = y;
    }
  }
  return (l, t, r, b);
}

/// Sutherland–Hodgman: the part of each ring on one side of the line
/// `coordinate[axis] = c` (the far side if [above]). Rings left with fewer
/// than three points are dropped.
List<Float64List> _clip(
  List<Float64List> rings,
  double c,
  int axis,
  bool above,
) {
  final out = <Float64List>[];
  bool inside(double v) => above ? v >= c : v <= c;
  for (final ring in rings) {
    final n = ring.length ~/ 2;
    if (n < 3) continue;
    final pts = <double>[];
    var px = ring[2 * (n - 1)], py = ring[2 * (n - 1) + 1];
    var pIn = inside(axis == 0 ? px : py);
    for (var k = 0; k < n; k++) {
      final x = ring[2 * k], y = ring[2 * k + 1];
      final cIn = inside(axis == 0 ? x : y);
      if (cIn != pIn) {
        final pv = axis == 0 ? px : py, cv = axis == 0 ? x : y;
        final f = (c - pv) / (cv - pv);
        if (axis == 0) {
          pts.addAll([c, py + (y - py) * f]);
        } else {
          pts.addAll([px + (x - px) * f, c]);
        }
      }
      if (cIn) pts.addAll([x, y]);
      px = x;
      py = y;
      pIn = cIn;
    }
    if (pts.length >= 6) out.add(Float64List.fromList(pts));
  }
  return out;
}

/// Douglas–Peucker on [line]; closed rings keep their first point. With
/// [tolerance] 0 only repeated points go.
Float64List _simplify(Float64List line, double tolerance) {
  final n = line.length ~/ 2;
  if (n <= 2) return line;
  if (tolerance <= 0) {
    final out = <double>[line[0], line[1]];
    for (var k = 1; k < n; k++) {
      final x = line[2 * k], y = line[2 * k + 1];
      if (x != out[out.length - 2] || y != out[out.length - 1]) {
        out.addAll([x, y]);
      }
    }
    return out.length == line.length ? line : Float64List.fromList(out);
  }
  final keep = Uint8List(n)
    ..[0] = 1
    ..[n - 1] = 1;
  final t2 = tolerance * tolerance;
  final stack = <int>[0, n - 1];
  while (stack.isNotEmpty) {
    final b = stack.removeLast(), a = stack.removeLast();
    final ax = line[2 * a], ay = line[2 * a + 1];
    final dx = line[2 * b] - ax, dy = line[2 * b + 1] - ay;
    final len2 = dx * dx + dy * dy;
    var worst = -1.0;
    var at = -1;
    for (var k = a + 1; k < b; k++) {
      final px = line[2 * k] - ax, py = line[2 * k + 1] - ay;
      double d2;
      if (len2 == 0) {
        d2 = px * px + py * py;
      } else {
        final cross = px * dy - py * dx;
        d2 = cross * cross / len2;
      }
      if (d2 > worst) {
        worst = d2;
        at = k;
      }
    }
    if (at >= 0 && worst > t2) {
      keep[at] = 1;
      stack
        ..addAll([a, at])
        ..addAll([at, b]);
    }
  }
  final out = Float64List(keep.fold<int>(0, (s, k) => s + k) * 2);
  var o = 0;
  for (var k = 0; k < n; k++) {
    if (keep[k] == 1) {
      out[o++] = line[2 * k];
      out[o++] = line[2 * k + 1];
    }
  }
  return out;
}

/// A ring smaller than [tolerance] each way is not worth drawing.
bool _tiny(Float64List ring, double tolerance) {
  if (tolerance <= 0) return false;
  final (l, t, r, b) = _bounds([ring]);
  return r - l < tolerance && b - t < tolerance;
}

/// [ring] closed and cut where it runs along the date line or the
/// projection's top or bottom edge: those are where Natural Earth splits
/// land, not shores.
Iterable<Float64List> _shore(Float64List ring) sync* {
  final n = ring.length ~/ 2;
  if (n < 2) return;
  const e = 1e-3;
  bool cut(int a, int b) {
    final ax = ring[2 * a], ay = ring[2 * a + 1];
    final bx = ring[2 * b], by = ring[2 * b + 1];
    bool edgeX(double x) => x <= e || x >= worldSize - e;
    bool edgeY(double y) => y <= e || y >= worldSize - e;
    return (edgeX(ax) && edgeX(bx) && (ax - bx).abs() < e) ||
        (edgeY(ay) && edgeY(by) && (ay - by).abs() < e);
  }

  var run = <double>[ring[0], ring[1]];
  for (var k = 1; k <= n; k++) {
    final i = k % n;
    if (cut(k - 1, i)) {
      if (run.length >= 4) yield Float64List.fromList(run);
      run = [ring[2 * i], ring[2 * i + 1]];
    } else {
      run.addAll([ring[2 * i], ring[2 * i + 1]]);
    }
  }
  if (run.length >= 4) yield Float64List.fromList(run);
}

BasemapLevel _level(
  LevelSpec spec,
  List<_Poly> land,
  List<_Poly> lakes,
  List<Float64List> borders,
) {
  final t = spec.tolerance;
  final cells = _CellBuilder(spec.grid);
  void polygons(List<_Poly> polys, Map<int, List<Float64List>> fills) {
    for (final p in polys) {
      final rings = [
        for (final r in p)
          if (!_tiny(r, 2 * t)) _simplify(r, t),
      ].where((r) => r.length >= 6).toList();
      if (rings.isEmpty) continue;
      cells.fill(fills, rings);
      for (final r in rings) {
        for (final s in _shore(r)) {
          cells.line(cells._coast, s);
        }
      }
    }
  }

  polygons(land, cells._land);
  polygons(lakes, cells._lakes);
  for (final l in borders) {
    final s = _simplify(l, t);
    if (s.length >= 4) cells.line(cells._borders, s);
  }
  return BasemapLevel(spec.minZoom, cells.cells());
}
