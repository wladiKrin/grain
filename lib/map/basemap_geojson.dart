import 'basemap.dart';
import 'geo.dart';

/// The offline basemap as GeoJSON, for MapLibre's GeoJSON sources: land
/// and lake areas, their shores, the land borders and the places.
///
/// Pure Dart (no Flutter), so it runs off the UI thread. Written once to
/// the cache directory ([writeBasemapFiles]) rather than bundled: the APK
/// keeps the compact `basemap.bin`.
class BasemapGeoJson {
  BasemapGeoJson._(this.layers, this.placeZooms);

  factory BasemapGeoJson.of(Basemap map) {
    final zooms = <int>{for (final p in map.places) placeZoom(p)}.toList()
      ..sort();
    return BasemapGeoJson._({
      'land': _polygons(map.land),
      'lakes': _polygons(map.lakes),
      'coast': _lines([
        for (final p in [...map.land, ...map.lakes])
          for (final r in [p.outline, ...p.holes]) ...shoreOf(r),
      ]),
      'borders': _lines(map.borders),
      'places': _places(map.places),
    }, zooms);
  }

  /// Each layer's GeoJSON text, by name: land, lakes, coast, borders,
  /// places.
  final Map<String, String> layers;

  /// The [placeZoom]s the places have, smallest first: one label layer
  /// each.
  final List<int> placeZooms;

  static const names = ['land', 'lakes', 'coast', 'borders', 'places'];

  /// The MapLibre zoom a place is labelled from. Natural Earth's zooms are
  /// for 256-pixel tiles, one more than MapLibre's for the same scale.
  static int placeZoom(Place p) => (p.minZoom - 1).floor().clamp(0, 22);
}

/// [ring] closed and cut where it runs along the date line or the
/// Mercator top or bottom edge: those are where Natural Earth splits land,
/// not shores.
List<List<GeoPoint>> shoreOf(List<GeoPoint> ring) {
  final n = ring.length;
  if (n < 2) return const [];
  const e = 1e-3;
  bool cut(GeoPoint a, GeoPoint b) =>
      (a.longitude.abs() >= 180 - e && (a.longitude - b.longitude).abs() < e) ||
      (a.latitude.abs() >= maxLatitude - e &&
          (a.latitude - b.latitude).abs() < e);
  final closed = ring.first == ring.last ? ring : [...ring, ring.first];
  final out = <List<GeoPoint>>[];
  var run = <GeoPoint>[closed.first];
  for (var i = 1; i < closed.length; i++) {
    if (cut(closed[i - 1], closed[i])) {
      if (run.length >= 2) out.add(run);
      run = [closed[i]];
    } else {
      run.add(closed[i]);
    }
  }
  if (run.length >= 2) out.add(run);
  return out;
}

void _point(StringBuffer b, GeoPoint p) {
  b
    ..write('[')
    ..write(_num(p.longitude))
    ..write(',')
    ..write(_num(p.latitude))
    ..write(']');
}

/// Degrees at the basemap's 1e-4 resolution, without trailing zeros.
String _num(double v) {
  final s = v.toStringAsFixed(4);
  var end = s.length;
  while (s[end - 1] == '0') {
    end--;
  }
  if (s[end - 1] == '.') end--;
  return s.substring(0, end);
}

void _line(StringBuffer b, List<GeoPoint> points, {bool close = false}) {
  b.write('[');
  for (var i = 0; i < points.length; i++) {
    if (i > 0) b.write(',');
    _point(b, points[i]);
  }
  if (close && points.isNotEmpty && points.first != points.last) {
    b.write(',');
    _point(b, points.first);
  }
  b.write(']');
}

String _polygons(List<MapPolygon> polygons) {
  final b = StringBuffer('{"type":"FeatureCollection","features":[');
  var first = true;
  for (final p in polygons) {
    if (p.outline.length < 3) continue;
    if (!first) b.write(',');
    first = false;
    b.write('{"type":"Feature","properties":{},"geometry":');
    b.write('{"type":"Polygon","coordinates":[');
    _line(b, p.outline, close: true);
    for (final h in p.holes) {
      if (h.length < 3) continue;
      b.write(',');
      _line(b, h, close: true);
    }
    b.write(']}}');
  }
  b.write(']}');
  return b.toString();
}

String _lines(List<List<GeoPoint>> lines) {
  final b = StringBuffer(
    '{"type":"FeatureCollection","features":[{"type":"Feature",'
    '"properties":{},"geometry":{"type":"MultiLineString","coordinates":[',
  );
  var first = true;
  for (final l in lines) {
    if (l.length < 2) continue;
    if (!first) b.write(',');
    first = false;
    _line(b, l);
  }
  b.write(']}}]}');
  return b.toString();
}

String _places(List<Place> places) {
  final b = StringBuffer('{"type":"FeatureCollection","features":[');
  for (var i = 0; i < places.length; i++) {
    final p = places[i];
    if (i > 0) b.write(',');
    b
      ..write('{"type":"Feature","properties":{"name":')
      ..write(_string(p.name))
      ..write(',"capital":')
      ..write(p.capital)
      ..write(',"z":')
      ..write(BasemapGeoJson.placeZoom(p))
      ..write(',"rank":')
      ..write(i)
      ..write('},"geometry":{"type":"Point","coordinates":');
    _point(b, p.position);
    b.write('}}');
  }
  b.write(']}');
  return b.toString();
}

String _string(String s) {
  final b = StringBuffer('"');
  for (final c in s.runes) {
    switch (c) {
      case 0x22:
        b.write(r'\"');
      case 0x5C:
        b.write(r'\\');
      case < 0x20:
        b.write('\\u${c.toRadixString(16).padLeft(4, '0')}');
      default:
        b.writeCharCode(c);
    }
  }
  b.write('"');
  return b.toString();
}
