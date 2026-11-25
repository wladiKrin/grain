import 'package:latlong2/latlong.dart';

import '../rolls/model.dart';

/// A logged location on the map: a roll's frame or a saved reading.
class MapPoint {
  MapPoint._frame(Roll this.roll, Frame this.frame, GeoFix fix)
    : reading = null,
      _fix = fix,
      position = LatLng(fix.latitude, fix.longitude);

  MapPoint._reading(SavedReading this.reading, GeoFix fix)
    : roll = null,
      frame = null,
      _fix = fix,
      position = LatLng(fix.latitude, fix.longitude);

  /// Null for a saved reading.
  final Roll? roll;
  final Frame? frame;
  final SavedReading? reading;
  final LatLng position;
  final GeoFix _fix;

  bool get isReading => reading != null;

  /// Stable across rebuilds: the record's id.
  String get id => frame?.id ?? reading!.id;

  String get camera => frame?.bodyName ?? reading!.bodyName;

  /// When it was taken, and the zone offset then (minutes).
  DateTime? get takenAt => frame?.takenAt ?? reading?.takenAt;
  int get utcOffsetMinutes =>
      frame?.utcOffsetMinutes ?? reading?.utcOffsetMinutes ?? 0;

  @override
  bool operator ==(Object other) =>
      other is MapPoint &&
      other.roll == roll &&
      other.frame == frame &&
      other.reading == reading &&
      other._fix == _fix;

  @override
  int get hashCode => Object.hash(roll, frame, reading, _fix);
}

/// The located frames of [rolls] and the located [readings]; records without
/// a location are left out. Frames come in roll and frame order, then the
/// readings.
List<MapPoint> mapPoints(
  List<(Roll, List<Frame>)> rolls, [
  List<SavedReading> readings = const [],
]) => [
  for (final (r, frames) in rolls)
    for (final f in frames)
      if (f.location case final fix?) MapPoint._frame(r, f, fix),
  for (final s in readings)
    if (s.location case final fix?) MapPoint._reading(s, fix),
];
