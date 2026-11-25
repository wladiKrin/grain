import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/map/map_markers.dart';
import 'package:grain/map/map_points.dart';
import 'package:grain/map/map_styles.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../rolls/support.dart';

const _munich = GeoFix(latitude: 48.137, longitude: 11.575);
const _near = GeoFix(latitude: 48.13702, longitude: 11.57502);
const _berlin = GeoFix(latitude: 52.52, longitude: 13.405);

SavedReading _reading(String id, GeoFix at) => SavedReading(
  id: id,
  bodyId: 'b1',
  bodyMake: 'Canon',
  bodyModel: 'A-1',
  format: FilmFormat.f135,
  exposure: const Exposure(aperture: 5.6),
  takenAt: t0.add(const Duration(hours: 10)),
  utcOffsetMinutes: 0,
  location: at,
  updatedAt: t0,
);

void main() {
  final f = frames([1, 2, 3]);
  final points = mapPoints(
    [
      (
        roll(number: 3),
        [
          f[0].copyWith(
            id: 'f1',
            location: () => _munich,
            takenAt: () => t0.add(const Duration(hours: 9)),
          ),
          f[1].copyWith(id: 'f2', location: () => _near),
          f[2].copyWith(
            id: 'f3',
            location: () => _berlin,
            takenAt: () => t0.add(const Duration(hours: 8)),
          ),
        ],
      ),
    ],
    [_reading('s1', _munich)],
  );

  List<Map<String, Object?>> features(Map<String, Object?> fc) =>
      (fc['features']! as List).cast<Map<String, Object?>>();
  Map<String, Object?> props(Map<String, Object?> f) =>
      (f['properties']! as Map).cast<String, Object?>();

  for (final b in Brightness.values) {
    test('frames and readings are told apart in the $b palette', () {
      final g = GrainPalette.of(b);
      final fc = markerGeoJson(points, const {}, g);
      expect(fc['type'], 'FeatureCollection');
      final fs = features(fc);
      // Readings first (drawn under the frames).
      expect(fs.map((f) => f['id']), ['s1', 'f1', 'f2', 'f3']);
      final reading = props(fs.first), frame = props(fs[1]);
      expect(reading['label'], 'Saved reading');
      expect(frame['label'], 'Roll 3, frame 1');
      expect(frame['fill'], cssColor(g.accent));
      expect(frame['ring'], cssColor(g.ground));
      expect(reading['fill'], cssColor(g.ground));
      expect(reading['ring'], cssColor(g.accent));
      expect(frame['stroke'], frameStroke);
      expect(reading['stroke'], readingStroke);
      // Both 16 across.
      expect(2 * (frame['radius']! as double) + 2 * frameStroke, 16);
      expect(2 * (reading['radius']! as double) + 2 * readingStroke, 16);
      expect(fs[1]['geometry'], {
        'type': 'Point',
        'coordinates': [_munich.longitude, _munich.latitude],
      });
    });
  }

  test('a selected marker is bigger, haloed in ink, and on top', () {
    final g = GrainPalette.of(Brightness.light);
    final fs = features(markerGeoJson(points, {'f1'}, g));
    expect(fs.last['id'], 'f1');
    final p = props(fs.last);
    expect(p['selected'], isTrue);
    expect(p['order'], 2);
    expect(2 * (p['radius']! as double) + 2 * frameStroke, 20);
    expect(p['halo'], (p['radius']! as double) + frameStroke + haloWidth);
    expect(p['haloColor'], cssColor(g.ink));
    for (final f in fs.take(3)) {
      expect(props(f)['selected'], isFalse);
      expect((props(f)['order']! as int), lessThan(2));
    }
  });

  test('the points within a marker of a tap, oldest first, undated last', () {
    final f1 = points.firstWhere((p) => p.id == 'f1');
    final near = pointsNear(f1, points, 13);
    expect(near.map((p) => p.id), ['f1', 's1', 'f2']);
    // Close in, the spots part.
    expect(pointsNear(f1, points, 19).map((p) => p.id), ['f1', 's1']);
    final f3 = points.firstWhere((p) => p.id == 'f3');
    expect(pointsNear(f3, points, 13), [f3]);
    // At the world view, everything is at one spot.
    expect(pointsNear(f3, points, 0), hasLength(4));
  });
}
