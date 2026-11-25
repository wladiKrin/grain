// Builds assets/map/basemap.bin, the offline basemap, from Natural Earth
// GeoJSON (public domain). Reproduce with:
//
//   tool/basemap/fetch.sh build/natural-earth
//   dart run tool/basemap/encode.dart build/natural-earth assets/map/basemap.bin
//
// The 1:50m land, lakes and land borders are kept as they are (about 100k
// points; no further simplification is needed at this scale), rounded to
// 1e-4 degree. Places come from the 1:10m populated places, with the zoom
// Natural Earth suggests labelling each from.
import 'dart:convert';
import 'dart:io';

import 'package:grain/map/basemap.dart';
import 'package:latlong2/latlong.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: encode.dart <natural-earth dir> <out.bin>');
    exit(64);
  }
  final dir = args[0];
  List<Map<String, Object?>> features(String name) =>
      ((jsonDecode(File('$dir/$name.geojson').readAsStringSync())
                  as Map)['features']
              as List)
          .cast<Map<String, Object?>>();

  final map = Basemap(
    land: _polygons(features('ne_50m_land')),
    lakes: _polygons(features('ne_50m_lakes')),
    borders: _lines(features('ne_50m_admin_0_boundary_lines_land')),
    places: _places(features('ne_10m_populated_places_simple')),
  );
  final bytes = map.encode();
  File(args[1])
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  final points =
      [...map.land, ...map.lakes].fold<int>(0, (n, p) => n + p.outline.length) +
      map.borders.fold<int>(0, (n, l) => n + l.length);
  stdout.writeln(
    '${args[1]}: ${bytes.length} bytes; ${map.land.length} land, '
    '${map.lakes.length} lakes, ${map.borders.length} borders, '
    '${map.places.length} places, ~$points points',
  );
}

Map<String, Object?> _geometry(Map<String, Object?> f) =>
    f['geometry']! as Map<String, Object?>;

List<LatLng> _ring(Object? coords) => [
  for (final c in coords! as List)
    LatLng(
      ((c as List)[1] as num).toDouble().clamp(-90, 90),
      (c[0] as num).toDouble().clamp(-180, 180),
    ),
];

MapPolygon _polygon(Object? rings) {
  final r = rings! as List;
  return MapPolygon(_ring(r.first), [for (final h in r.skip(1)) _ring(h)]);
}

List<MapPolygon> _polygons(List<Map<String, Object?>> fs) => [
  for (final f in fs)
    ...switch (_geometry(f)) {
      {'type': 'Polygon', 'coordinates': final c} => [_polygon(c)],
      {'type': 'MultiPolygon', 'coordinates': final List c} => [
        for (final p in c) _polygon(p),
      ],
      final g => throw FormatException('unexpected ${g['type']}'),
    },
];

List<List<LatLng>> _lines(List<Map<String, Object?>> fs) => [
  for (final f in fs)
    ...switch (_geometry(f)) {
      {'type': 'LineString', 'coordinates': final c} => [_ring(c)],
      {'type': 'MultiLineString', 'coordinates': final List c} => [
        for (final l in c) _ring(l),
      ],
      final g => throw FormatException('unexpected ${g['type']}'),
    },
];

List<Place> _places(List<Map<String, Object?>> fs) {
  final rows = [
    for (final f in fs)
      (
        place: Place(
          name: (f['properties']! as Map)['name'] as String,
          position: _ring([(_geometry(f)['coordinates']! as List)]).single,
          minZoom: ((f['properties']! as Map)['min_zoom'] as num).toDouble(),
          capital: ((f['properties']! as Map)['adm0cap'] as num? ?? 0) > 0,
        ),
        pop: ((f['properties']! as Map)['pop_max'] as num? ?? 0).toInt(),
      ),
  ];
  // Most prominent first: the labeller draws in this order.
  rows.sort((a, b) {
    final z = a.place.minZoom.compareTo(b.place.minZoom);
    if (z != 0) return z;
    if (a.place.capital != b.place.capital) return a.place.capital ? -1 : 1;
    return b.pop.compareTo(a.pop);
  });
  return [for (final r in rows) r.place];
}
