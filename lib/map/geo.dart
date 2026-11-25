import 'dart:math' as math;

/// A position in degrees: latitude north, longitude east.
///
/// Pure Dart (no Flutter), so `tool/basemap/` can use it.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude, longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// Where the map looks: its centre and MapLibre zoom (the world is
/// [mapTileSize] × 2^zoom logical pixels across).
class CameraView {
  const CameraView(this.center, this.zoom);

  final GeoPoint center;
  final double zoom;

  @override
  bool operator ==(Object other) =>
      other is CameraView && other.center == center && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(center, zoom);

  @override
  String toString() => 'CameraView($center, $zoom)';
}

/// MapLibre's world at zoom 0, in logical pixels.
const mapTileSize = 512.0;

/// Web Mercator's edge latitude.
const maxLatitude = 85.0511287798;

/// [p] in Web Mercator units: x east from the date line, y south from the
/// top edge, both 0 to 1 across the world.
(double, double) mercator(GeoPoint p) {
  final lat = p.latitude.clamp(-maxLatitude, maxLatitude);
  final s = math.sin(lat * math.pi / 180);
  return (
    (p.longitude + 180) / 360,
    .5 - math.log((1 + s) / (1 - s)) / (4 * math.pi),
  );
}

/// The inverse of [mercator].
GeoPoint fromMercator(double x, double y) {
  final n = math.pi - 2 * math.pi * y;
  return GeoPoint(
    180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n))),
    x * 360 - 180,
  );
}

/// The camera that shows all of [positions] in a [width] × [height] map,
/// clear of the [left], [top], [right] and [bottom] margins, at most
/// [maxZoom]. A single spot (or several at one place) is fitted as a small
/// area around it, so the zoom stays finite whatever the map's size.
CameraView fitCamera(
  List<GeoPoint> positions, {
  required double width,
  required double height,
  double left = 48,
  double top = 48,
  double right = 48,
  double bottom = 160,
  double maxZoom = 13,
}) {
  if (positions.isEmpty) return const CameraView(GeoPoint(30, 0), 1);
  var s = positions.first.latitude, n = s;
  var w = positions.first.longitude, e = w;
  for (final p in positions) {
    s = math.min(s, p.latitude);
    n = math.max(n, p.latitude);
    w = math.min(w, p.longitude);
    e = math.max(e, p.longitude);
  }
  if (n - s < 1e-4 && e - w < 1e-4) {
    final lat = (n + s) / 2, lon = (e + w) / 2;
    s = lat - .005;
    n = lat + .005;
    w = lon - .005;
    e = lon + .005;
  }
  final (x0, y0) = mercator(GeoPoint(n, w));
  final (x1, y1) = mercator(GeoPoint(s, e));
  final spanX = (x1 - x0) * mapTileSize, spanY = (y1 - y0) * mapTileSize;
  final roomX = math.max(1.0, width - left - right);
  final roomY = math.max(1.0, height - top - bottom);
  var zoom = maxZoom;
  if (spanX > 0) zoom = math.min(zoom, _log2(roomX / spanX));
  if (spanY > 0) zoom = math.min(zoom, _log2(roomY / spanY));
  zoom = zoom.clamp(0, maxZoom);
  // The area's centre in the room left, moved to the map's centre: the
  // margins shift it by half their difference.
  final scale = mapTileSize * math.pow(2, zoom);
  final cx = (x0 + x1) / 2 + (right - left) / 2 / scale;
  final cy = (y0 + y1) / 2 + (bottom - top) / 2 / scale;
  return CameraView(fromMercator(cx, cy.clamp(0, 1)), zoom);
}

double _log2(double v) => math.log(v) / math.ln2;

/// The distance between [a] and [b] on a map at [zoom], in logical pixels
/// (the map is never rotated or tilted). East and west it takes the way
/// round the date line if that is shorter, as the map repeats.
double screenDistance(GeoPoint a, GeoPoint b, double zoom) {
  final (ax, ay) = mercator(a);
  final (bx, by) = mercator(b);
  var dx = (ax - bx).abs();
  if (dx > .5) dx = 1 - dx;
  final scale = mapTileSize * math.pow(2, zoom);
  return math.sqrt(dx * dx + (ay - by) * (ay - by)) * scale;
}
