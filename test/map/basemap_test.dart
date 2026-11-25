import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/map/basemap.dart';
import 'package:grain/map/basemap_files.dart';
import 'package:grain/map/geo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sample = Basemap(
    land: [
      MapPolygon(
        [GeoPoint(0, 0), GeoPoint(10, 0), GeoPoint(10, 10), GeoPoint(0, 0)],
        [
          [GeoPoint(2, 2), GeoPoint(3, 2), GeoPoint(3, 3)],
        ],
      ),
      MapPolygon([
        GeoPoint(-89.9, -179.99),
        GeoPoint(-60, 179.99),
        GeoPoint(-70, 0),
      ]),
    ],
    lakes: [
      MapPolygon([
        GeoPoint(46.5, 6.2),
        GeoPoint(46.3, 6.9),
        GeoPoint(46.2, 6.1),
      ]),
    ],
    borders: [
      [GeoPoint(47.6, 7.6), GeoPoint(47.5, 9.6), GeoPoint(47.27, 10.17)],
      [],
    ],
    places: [
      Place(
        name: 'Berlin',
        position: GeoPoint(52.5218, 13.4015),
        minZoom: 1.7,
        capital: true,
      ),
      Place(
        name: 'São Paulo',
        position: GeoPoint(-23.5587, -46.625),
        minZoom: 2,
      ),
      Place(name: '東京', position: GeoPoint(35.685, 139.7514), minZoom: 1.7),
    ],
  );

  void expectNear(GeoPoint a, GeoPoint b) {
    expect(a.latitude, closeTo(b.latitude, 1e-4));
    expect(a.longitude, closeTo(b.longitude, 1e-4));
  }

  test('round-trips every layer to 1e-4 degree', () {
    final back = Basemap.decode(sample.encode());
    expect(back.land, hasLength(2));
    expect(back.land[0].outline, hasLength(4));
    expect(back.land[0].holes.single, hasLength(3));
    expect(back.land[1].holes, isEmpty);
    for (var i = 0; i < 3; i++) {
      expectNear(back.land[1].outline[i], sample.land[1].outline[i]);
    }
    expectNear(back.lakes.single.outline[1], const GeoPoint(46.3, 6.9));
    expect(back.borders.map((b) => b.length), [3, 0]);
    expectNear(back.borders[0][2], const GeoPoint(47.27, 10.17));
    expect(back.places.map((p) => p.name), ['Berlin', 'São Paulo', '東京']);
    expect(back.places.map((p) => p.capital), [true, false, false]);
    expect(back.places.map((p) => p.minZoom), [1.7, 2, 1.7]);
    expectNear(back.places[1].position, const GeoPoint(-23.5587, -46.625));
  });

  test('an empty basemap is 9 bytes', () {
    final b = const Basemap().encode();
    expect(b, hasLength(9));
    expect(Basemap.decode(b).places, isEmpty);
  });

  test('rejects other files, other versions, truncated and padded data', () {
    final good = sample.encode();
    expect(
      () => Basemap.decode(Uint8List.fromList('PK\x03\x04'.codeUnits)),
      throwsFormatException,
    );
    expect(
      () => Basemap.decode(Uint8List.fromList([...good.take(4), 2, 0])),
      throwsFormatException,
    );
    expect(
      () => Basemap.decode(Uint8List.sublistView(good, 0, good.length - 3)),
      throwsFormatException,
    );
    expect(
      () => Basemap.decode(Uint8List.fromList([...good, 0])),
      throwsFormatException,
    );
  });

  group('the bundled asset', () {
    late Basemap map;
    setUpAll(() async {
      final data = await rootBundle.load(basemapAsset);
      map = Basemap.decode(data.buffer.asUint8List());
    });

    test('stays small', () {
      expect(File(basemapAsset).lengthSync(), lessThan(1024 * 1024));
    });

    test('holds the Natural Earth layers', () {
      expect(map.land.length, greaterThan(1000));
      expect(map.lakes.length, greaterThan(300));
      expect(map.borders.length, greaterThan(300));
      expect(map.places.length, greaterThan(7000));
    });

    test('places are where they belong, most prominent first', () {
      final berlin = map.places.firstWhere((p) => p.name == 'Berlin');
      expect(berlin.capital, isTrue);
      expectNear(
        GeoPoint(
          (berlin.position.latitude * 10).roundToDouble() / 10,
          (berlin.position.longitude * 10).roundToDouble() / 10,
        ),
        const GeoPoint(52.5, 13.4),
      );
      for (var i = 1; i < map.places.length; i++) {
        expect(
          map.places[i].minZoom,
          greaterThanOrEqualTo(map.places[i - 1].minZoom),
        );
      }
    });
  });
}
