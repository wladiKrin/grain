import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/map/map_points.dart';
import 'package:grain/rolls/model.dart';
import 'package:latlong2/latlong.dart';

import '../rolls/support.dart';

const _here = GeoFix(latitude: 48.137, longitude: 11.575, accuracy: 12);
const _there = GeoFix(latitude: -33.86, longitude: 151.21);

SavedReading _reading(String id, GeoFix? fix) => SavedReading(
  id: id,
  bodyId: 'b2',
  bodyMake: 'Nikon',
  bodyModel: 'FM2',
  format: FilmFormat.f135,
  exposure: const Exposure(aperture: 8),
  takenAt: t0,
  utcOffsetMinutes: 60,
  location: fix,
  updatedAt: t0,
);

void main() {
  final r1 = roll();
  final r2 = roll(number: 2).copyWith(id: 'r2');

  test('only located frames and readings, frames first', () {
    final f = frames([1, 2, 3]);
    final located = [
      f[0].copyWith(location: () => _here),
      f[1],
      f[2].copyWith(location: () => _there),
    ];
    final other = frames([1]).map((x) => x.copyWith(rollId: 'r2')).toList();
    final points = mapPoints(
      [(r1, located), (r2, other)],
      [_reading('s1', null), _reading('s2', _there)],
    );
    expect(points.map((p) => p.id), ['f0', 'f2', 's2']);
    expect(points[0].position, const LatLng(48.137, 11.575));
    expect(points[0].roll, r1);
    expect(points[0].frame!.number, 1);
    expect(points[0].isReading, isFalse);
    expect(points[0].camera, 'Canon A-1');
    expect(points[2].isReading, isTrue);
    expect(points[2].roll, isNull);
    expect(points[2].camera, 'Nikon FM2');
    expect(points[2].takenAt, t0);
    expect(points[2].utcOffsetMinutes, 60);
    expect(points[2].position, const LatLng(-33.86, 151.21));
  });

  test('nothing located gives no points', () {
    expect(
      mapPoints(
        [
          (r1, frames([1, 2])),
        ],
        [_reading('s', null)],
      ),
      isEmpty,
    );
    expect(mapPoints([]), isEmpty);
  });

  test('a point equals one built from the same records', () {
    final f = frames([1]).single.copyWith(location: () => _here);
    expect(
      mapPoints([
        (r1, [f]),
      ]),
      mapPoints([
        (r1, [f]),
      ]),
    );
    final moved = f.copyWith(location: () => _there);
    expect(
      mapPoints([
        (r1, [f]),
      ]),
      isNot(
        mapPoints([
          (r1, [moved]),
        ]),
      ),
    );
  });
}
