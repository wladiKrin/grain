import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/map/basemap.dart';
import 'package:grain/map/basemap_files.dart';
import 'package:grain/map/basemap_geojson.dart';
import 'package:grain/map/geo.dart';
import 'package:grain/map/glyphs.dart';

const _map = Basemap(
  land: [
    MapPolygon(
      [GeoPoint(40, 0), GeoPoint(60, 0), GeoPoint(60, 20), GeoPoint(40, 20)],
      [
        [GeoPoint(45, 5), GeoPoint(46, 5), GeoPoint(46, 6)],
      ],
    ),
    // Cut by Natural Earth along the date line: no shore there.
    MapPolygon([
      GeoPoint(60, 170),
      GeoPoint(60, 180),
      GeoPoint(70, 180),
      GeoPoint(70, 170),
    ]),
  ],
  lakes: [
    MapPolygon([GeoPoint(47.5, 9), GeoPoint(47.7, 9.5), GeoPoint(47.4, 9.6)]),
  ],
  borders: [
    [GeoPoint(44, 2), GeoPoint(44, 18)],
  ],
  places: [
    Place(
      name: 'Berlin',
      position: GeoPoint(52.5218, 13.4015),
      minZoom: 1.7,
      capital: true,
    ),
    Place(name: 'Say "Kraków"', position: GeoPoint(50.06, 19.94), minZoom: 5),
  ],
);

Map<String, Object?> _decode(String s) => jsonDecode(s) as Map<String, Object?>;

List<Map<String, Object?>> _features(String s) =>
    (_decode(s)['features']! as List).cast<Map<String, Object?>>();

Map<String, Object?> _geometry(Map<String, Object?> f) =>
    (f['geometry']! as Map).cast<String, Object?>();

void main() {
  final geo = BasemapGeoJson.of(_map);

  test('land and lakes are polygons with their holes, rings closed, '
      'longitude first', () {
    final land = _features(geo.layers['land']!);
    expect(land, hasLength(2));
    final rings = _geometry(land.first)['coordinates']! as List;
    expect(rings, hasLength(2));
    expect((rings.first as List).first, [0, 40]);
    expect((rings.first as List).last, [0, 40]);
    expect((rings.first as List), hasLength(5));
    expect((rings.last as List).last, [5, 45]);
    expect(_features(geo.layers['lakes']!), hasLength(1));
  });

  test('shores leave out where land is cut at the date line', () {
    final coast =
        _geometry(_features(geo.layers['coast']!).single)['coordinates']!
            as List;
    for (final line in coast.cast<List>()) {
      for (var i = 1; i < line.length; i++) {
        final a = line[i - 1] as List, b = line[i] as List;
        expect(a[0] == 180 && b[0] == 180, isFalse, reason: '$line');
      }
    }
    // The square, its hole, the lake, and the date-line piece in two.
    expect(coast, hasLength(5));
  });

  test('borders are lines; places points with their zoom and rank', () {
    final borders = _geometry(_features(geo.layers['borders']!).single);
    expect(borders['type'], 'MultiLineString');
    expect(borders['coordinates'], [
      [
        [2, 44],
        [18, 44],
      ],
    ]);
    final places = _features(geo.layers['places']!);
    expect((places.first['properties']! as Map), {
      'name': 'Berlin',
      'capital': true,
      'z': 0,
      'rank': 0,
    });
    expect(_geometry(places.first)['coordinates'], [13.4015, 52.5218]);
    expect((places.last['properties']! as Map)['name'], 'Say "Kraków"');
    expect((places.last['properties']! as Map)['z'], 4);
    expect(geo.placeZooms, [0, 4]);
  });

  group('the bundled basemap', () {
    final bytes = File(basemapAsset).readAsBytesSync();

    test('converts to GeoJSON of a modest size', () {
      final all = BasemapGeoJson.of(Basemap.decode(bytes));
      final total = all.layers.values.fold<int>(0, (n, s) => n + s.length);
      expect(total, lessThan(8 * 1024 * 1024));
      for (final s in all.layers.values) {
        expect(_decode(s)['type'], 'FeatureCollection');
      }
      expect(all.placeZooms.first, 0);
      expect(all.placeZooms.last, lessThanOrEqualTo(9));
    });

    test('every place name is in the bundled glyphs', () {
      final map = Basemap.decode(bytes);
      final used = {0x2022, for (final p in map.places) ...p.name.runes};
      for (final c in used) {
        expect(
          glyphRanges,
          contains(c & ~0xFF),
          reason: 'U+${c.toRadixString(16)}',
        );
      }
      for (final font in [regularFont, boldFont]) {
        for (final start in glyphRanges) {
          final f = File('assets/map/glyphs/$font/$start-${start + 255}.pbf');
          expect(f.existsSync(), isTrue, reason: f.path);
          expect(f.lengthSync(), greaterThan(0));
        }
      }
    });

    test('written to the cache once, and again for another basemap', () {
      final dir = Directory.systemTemp.createTempSync('grain-basemap');
      addTearDown(() => dir.deleteSync(recursive: true));
      final first = writeBasemapFiles(bytes, dir);
      expect(first.data.keys, BasemapGeoJson.names);
      for (final url in first.data.values) {
        expect(url, startsWith('file:///'));
        expect(File.fromUri(Uri.parse(url)).existsSync(), isTrue);
      }
      final land = File.fromUri(Uri.parse(first.data['land']!));
      final written = land.lastModifiedSync();
      final again = writeBasemapFiles(bytes, dir);
      expect(again.data, first.data);
      expect(again.placeZooms, first.placeZooms);
      expect(land.lastModifiedSync(), written);

      final other = writeBasemapFiles(_map.encode(), dir);
      expect(other.data['land'], isNot(first.data['land']));
      expect(land.existsSync(), isFalse);
      expect(dir.listSync(), hasLength(1));
    });

    test('a write cut short is done again', () {
      final dir = Directory.systemTemp.createTempSync('grain-basemap');
      addTearDown(() => dir.deleteSync(recursive: true));
      final small = Uint8List.fromList(_map.encode());
      final first = writeBasemapFiles(small, dir);
      final lakes = File.fromUri(Uri.parse(first.data['lakes']!))..deleteSync();
      writeBasemapFiles(small, dir);
      expect(lakes.existsSync(), isTrue);
    });
  });
}
