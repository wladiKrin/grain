import '../ui/theme.dart';
import 'geo.dart';
import 'map_points.dart';
import 'map_styles.dart';

/// What a marker says to assistive technology, and in tests.
String pointLabel(MapPoint p) => p.isReading
    ? 'Saved reading'
    : 'Roll ${p.roll!.number}, frame ${p.frame!.label}';

/// Marker sizes, in logical pixels: a frame is a filled dot in the accent
/// with a ring of the ground colour, a saved reading a ring in the accent;
/// both 16 across, 20 when selected, which also gets an ink halo.
const frameRadius = 6.0, frameStroke = 2.0;
const readingRadius = 5.0, readingStroke = 3.0;
const selectedGrowth = 2.0, haloWidth = 1.5;

/// [shown] as the GeoJSON the marker layers draw: per point its id, label,
/// colours and sizes, and the order it is drawn in (readings under frames,
/// the selected ones on top).
Map<String, Object?> markerGeoJson(
  List<MapPoint> shown,
  Set<String> selected,
  GrainPalette g,
) {
  final accent = cssColor(g.accent), ground = cssColor(g.ground);
  final ink = cssColor(g.ink);
  Map<String, Object?> feature(MapPoint p) {
    final on = selected.contains(p.id);
    final reading = p.isReading;
    final r =
        (reading ? readingRadius : frameRadius) + (on ? selectedGrowth : 0);
    final stroke = reading ? readingStroke : frameStroke;
    return {
      'type': 'Feature',
      'id': p.id,
      'properties': {
        'id': p.id,
        'label': pointLabel(p),
        'reading': reading,
        'selected': on,
        'radius': r,
        'stroke': stroke,
        'halo': r + stroke + haloWidth,
        'haloColor': ink,
        'fill': reading ? ground : accent,
        'ring': reading ? accent : ground,
        'order': on ? 2 : (reading ? 0 : 1),
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [p.position.longitude, p.position.latitude],
      },
    };
  }

  final ordered = [
    for (final p in shown)
      if (p.isReading && !selected.contains(p.id)) p,
    for (final p in shown)
      if (!p.isReading && !selected.contains(p.id)) p,
    for (final p in shown)
      if (selected.contains(p.id)) p,
  ];
  return {
    'type': 'FeatureCollection',
    'features': [for (final p in ordered) feature(p)],
  };
}

/// How near on screen another point must be to [pointsNear] a tapped one.
const nearPixels = 16.0;

/// The points of [shown] drawn within a marker's reach of [tapped] at
/// [zoom], oldest first (undated last): the card lists them all, so frames
/// logged at one spot can each be opened.
List<MapPoint> pointsNear(MapPoint tapped, List<MapPoint> shown, double zoom) {
  final near = [
    for (final q in shown)
      if (screenDistance(q.position, tapped.position, zoom) <= nearPixels) q,
  ]..sort(byTime);
  return near.isEmpty ? [tapped] : near;
}

/// Oldest first; undated (blank) frames last.
int byTime(MapPoint a, MapPoint b) => switch ((a.takenAt, b.takenAt)) {
  (final x?, final y?) => x.compareTo(y),
  (null, null) => 0,
  (null, _) => 1,
  (_, null) => -1,
};

/// Newest first, as the list of points shows them; undated (blank) frames
/// last.
int newestFirst(MapPoint a, MapPoint b) => switch ((a.takenAt, b.takenAt)) {
  (final x?, final y?) => y.compareTo(x),
  (null, null) => 0,
  (null, _) => 1,
  (_, null) => -1,
};
