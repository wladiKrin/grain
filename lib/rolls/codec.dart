import '../exposure/mode.dart';
import '../exposure/stops.dart';
import '../gear/model.dart';
import '../metering/reading.dart';
import 'model.dart';
import 'numbering.dart';

/// Thrown for a roll or reading file that is not valid; the message starts
/// with the path of the offending field.
class RollFormatException implements Exception {
  RollFormatException(this.message);
  final String message;

  @override
  String toString() => 'RollFormatException: $message';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// `+01:00` style offset.
String offsetLabel(int offsetMinutes) {
  final a = offsetMinutes.abs();
  return '${offsetMinutes < 0 ? '-' : '+'}${_two(a ~/ 60)}:${_two(a % 60)}';
}

String _local(DateTime utc, int offsetMinutes) {
  final l = utc.toUtc().add(Duration(minutes: offsetMinutes));
  return '${l.year.toString().padLeft(4, '0')}-${_two(l.month)}-${_two(l.day)}'
      'T${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
}

/// `2026-11-21T14:03:22+01:00`: the wall-clock time at [offsetMinutes] with
/// that offset. A sub-second part is appended only when present, so the
/// instant survives a round trip.
String isoWithOffset(DateTime utc, int offsetMinutes) {
  final u = utc.toUtc();
  var frac = '';
  if (u.millisecond != 0 || u.microsecond != 0) {
    final micros = u.millisecond * 1000 + u.microsecond;
    frac =
        '.${micros.toString().padLeft(6, '0').replaceAll(RegExp(r'0+$'), '')}';
  }
  final base = _local(u, offsetMinutes);
  return '$base$frac${offsetLabel(offsetMinutes)}';
}

Map<String, Object?> _bodyJson(
  String? id,
  String make,
  String model,
  FilmFormat f,
) => {'id': id, 'make': make, 'model': model, 'format': f.id};

Map<String, Object?>? _locationJson(GeoFix? g) => g == null
    ? null
    : {
        'latitude': g.latitude,
        'longitude': g.longitude,
        'accuracy': g.accuracy,
      };

String _modeId(MeterMode m) => switch (m) {
  MeterMode.aperturePriority => 'aperture-priority',
  MeterMode.shutterPriority => 'shutter-priority',
  MeterMode.manual => 'manual',
};

MeterMode? _modeById(String s) {
  for (final m in MeterMode.values) {
    if (_modeId(m) == s) return m;
  }
  return null;
}

Map<String, Object?>? _lensJson(Exposure e) =>
    e.lensId == null && e.lensMake == null && e.lensName == null
    ? null
    : {'id': e.lensId, 'make': e.lensMake, 'name': e.lensName};

/// The exposure part shared by frames and readings, EXIF-ready:
/// aperture → FNumber, exposureTime → ExposureTime, iso →
/// PhotographicSensitivity, focalLength → FocalLength, lens →
/// LensMake/LensModel.
Map<String, Object?> _exposureJson(Exposure e) => {
  'aperture': e.aperture,
  'shutter': e.shutter,
  'exposureTime': e.exposureTime,
  'iso': e.iso,
  'lens': _lensJson(e),
  'focalLength': e.focal,
  'mode': e.mode == null ? null : _modeId(e.mode!),
  'meteredEv': e.meteredEv,
  'offset': e.offset,
  'area': e.area?.name,
};

String _utcIso(DateTime d) => d.toUtc().toIso8601String();

/// A roll with its frames as JSON carrying everything needed to write EXIF
/// later: roll.body → Make/Model, frame.takenAt → DateTimeOriginal +
/// OffsetTimeOriginal, frame.aperture → FNumber, frame.exposureTime →
/// ExposureTime, frame.iso → PhotographicSensitivity, frame.focalLength →
/// FocalLength, frame.lens → LensMake/LensModel, frame.location → GPS*,
/// roll.film (box speed, push/pull) and frame.number for the film frame.
Map<String, Object?> rollToJson(Roll r, List<Frame> frames) => {
  'schema': 1,
  'type': 'grain-roll',
  'roll': {
    'id': r.id,
    'number': r.number,
    'film': {
      'stock': r.filmStock,
      'type': r.filmType.id,
      'boxIso': r.boxIso,
      'pushThirds': r.pushThirds,
      'pushStops': r.pushStops,
      'exposedIso': r.exposedIso,
      'latitudeUnderHalves': r.latitudeUnderHalves,
      'latitudeOverHalves': r.latitudeOverHalves,
    },
    'body': _bodyJson(r.bodyId, r.bodyMake, r.bodyModel, r.format),
    'size': r.size,
    'startFrame': r.startFrame.label,
    'status': r.status.name,
    'startedAt': _utcIso(r.startedAt),
    'finishedAt': r.finishedAt == null ? null : _utcIso(r.finishedAt!),
    'notes': r.notes,
    'updatedAt': _utcIso(r.updatedAt),
  },
  'frames': [
    for (final f in frames)
      {
        'id': f.id,
        'position': f.position,
        'number': f.label,
        'takenAt': f.takenAt == null
            ? null
            : f.utcOffsetMinutes == null
            ? _utcIso(f.takenAt!)
            : isoWithOffset(f.takenAt!, f.utcOffsetMinutes!),
        'utcOffsetMinutes': f.utcOffsetMinutes,
        ..._exposureJson(f.exposure),
        'note': f.note,
        'location': _locationJson(f.location),
        'snapshot': f.snapshot,
        'updatedAt': _utcIso(f.updatedAt),
      },
  ],
};

Map<String, Object?> readingToJson(SavedReading r) => {
  'schema': 1,
  'type': 'grain-reading',
  'id': r.id,
  'body': _bodyJson(r.bodyId, r.bodyMake, r.bodyModel, r.format),
  'takenAt': isoWithOffset(r.takenAt, r.utcOffsetMinutes),
  'utcOffsetMinutes': r.utcOffsetMinutes,
  ..._exposureJson(r.exposure),
  'note': r.note,
  'location': _locationJson(r.location),
  'snapshot': r.snapshot,
  'updatedAt': _utcIso(r.updatedAt),
};

// ---- parsing ----

Never _bad(String path, String message) =>
    throw RollFormatException('$path: $message');

Map<String, Object?> _map(Object? v, String path) {
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): e.value};
  }
  _bad(path, 'expected an object');
}

List<Object?> _list(Object? v, String path) =>
    v is List ? v : _bad(path, 'expected a list');

String _str(Map<String, Object?> m, String k, String p) {
  final v = m[k];
  return v is String ? v : _bad('$p$k', 'expected text');
}

String? _strOrNull(Map<String, Object?> m, String k, String p) {
  final v = m[k];
  if (v == null) return null;
  return v is String ? v : _bad('$p$k', 'expected text or null');
}

int _int(Map<String, Object?> m, String k, String p) {
  final v = m[k];
  return v is int ? v : _bad('$p$k', 'expected a whole number');
}

int? _intOrNull(Map<String, Object?> m, String k, String p) {
  final v = m[k];
  if (v == null) return null;
  return v is int ? v : _bad('$p$k', 'expected a whole number or null');
}

/// Optional half-stop count of roll.film within [min]…[max].
int? _halves(Map<String, Object?> film, String k, int min, int max) {
  final v = _intOrNull(film, k, 'roll.film.');
  if (v != null && (v < min || v > max)) {
    _bad('roll.film.$k', 'expected $min..$max');
  }
  return v;
}

double? _numOrNull(Map<String, Object?> m, String k, String p) {
  final v = m[k];
  if (v == null) return null;
  return v is num ? v.toDouble() : _bad('$p$k', 'expected a number or null');
}

DateTime _date(Map<String, Object?> m, String k, String p) {
  final v = m[k];
  final d = v is String ? DateTime.tryParse(v) : null;
  return d == null ? _bad('$p$k', 'expected a date') : d.toUtc();
}

DateTime? _dateOrNull(Map<String, Object?> m, String k, String p) =>
    m[k] == null ? null : _date(m, k, p);

FilmFormat _format(String id, String path) {
  for (final f in FilmFormat.values) {
    if (f.id == id) return f;
  }
  _bad(path, 'unknown film format "$id"');
}

GeoFix? _location(Map<String, Object?> m, String p) {
  if (m['location'] == null) return null;
  final l = _map(m['location'], '${p}location');
  final lat = _numOrNull(l, 'latitude', '${p}location.');
  final lon = _numOrNull(l, 'longitude', '${p}location.');
  if (lat == null || lon == null) {
    _bad('${p}location', 'needs latitude and longitude');
  }
  return GeoFix(
    latitude: lat,
    longitude: lon,
    accuracy: _numOrNull(l, 'accuracy', '${p}location.'),
  );
}

Exposure _exposure(Map<String, Object?> m, String p) {
  String? lensId, lensMake, lensName;
  if (m['lens'] != null) {
    final l = _map(m['lens'], '${p}lens');
    lensId = _strOrNull(l, 'id', '${p}lens.');
    lensMake = _strOrNull(l, 'make', '${p}lens.');
    lensName = _strOrNull(l, 'name', '${p}lens.');
  }
  MeterMode? mode;
  final modeId = _strOrNull(m, 'mode', p);
  if (modeId != null) {
    mode = _modeById(modeId) ?? _bad('${p}mode', 'unknown mode "$modeId"');
  }
  MeterArea? area;
  final areaId = _strOrNull(m, 'area', p);
  if (areaId != null) {
    area =
        MeterArea.values.where((a) => a.name == areaId).firstOrNull ??
        _bad('${p}area', 'unknown area "$areaId"');
  }
  return Exposure(
    mode: mode,
    aperture: _numOrNull(m, 'aperture', p),
    shutter: _strOrNull(m, 'shutter', p),
    exposureTime: _numOrNull(m, 'exposureTime', p),
    iso: _intOrNull(m, 'iso', p),
    lensId: lensId,
    lensMake: lensMake,
    lensName: lensName,
    focal: _numOrNull(m, 'focalLength', p),
    meteredEv: _numOrNull(m, 'meteredEv', p),
    offset: _numOrNull(m, 'offset', p),
    area: area,
  );
}

void _header(Map<String, Object?> m, String type) {
  if (m['type'] != type) _bad('type', 'not a $type file');
  if (m['schema'] != 1) _bad('schema', 'unsupported version');
}

(Roll, List<Frame>) rollFromJson(Object? json) {
  final top = _map(json, 'file');
  _header(top, 'grain-roll');
  final r = _map(top['roll'], 'roll');
  const rp = 'roll.';
  final id = _str(r, 'id', rp);
  final number = _int(r, 'number', rp);
  final film = _map(r['film'], 'roll.film');
  final body = _map(r['body'], 'roll.body');
  final filmType =
      FilmType.byId(_str(film, 'type', 'roll.film.')) ??
      _bad('roll.film.type', 'unknown film type');
  final startFrame =
      StartFrame.byLabel(_str(r, 'startFrame', rp)) ??
      _bad('roll.startFrame', 'expected 00, 0 or 1');
  final statusName = _str(r, 'status', rp);
  final status =
      RollStatus.values.where((s) => s.name == statusName).firstOrNull ??
      _bad('roll.status', 'unknown status');
  final roll = Roll(
    id: id,
    number: number,
    filmStock: _str(film, 'stock', 'roll.film.'),
    filmType: filmType,
    boxIso: _int(film, 'boxIso', 'roll.film.'),
    pushThirds: _int(film, 'pushThirds', 'roll.film.'),
    bodyId: _strOrNull(body, 'id', 'roll.body.'),
    bodyMake: _str(body, 'make', 'roll.body.'),
    bodyModel: _str(body, 'model', 'roll.body.'),
    format: _format(_str(body, 'format', 'roll.body.'), 'roll.body.format'),
    size: _int(r, 'size', rp),
    startFrame: startFrame,
    notes: _str(r, 'notes', rp),
    latitudeUnderHalves: _halves(
      film,
      'latitudeUnderHalves',
      latitudeUnderHalvesMin,
      0,
    ),
    latitudeOverHalves: _halves(
      film,
      'latitudeOverHalves',
      0,
      latitudeOverHalvesMax,
    ),
    status: status,
    startedAt: _date(r, 'startedAt', rp),
    finishedAt: _dateOrNull(r, 'finishedAt', rp),
    updatedAt: _date(r, 'updatedAt', rp),
  );
  final list = _list(top['frames'], 'frames');
  final frames = <Frame>[];
  for (var i = 0; i < list.length; i++) {
    final p = 'frames[$i].';
    final f = _map(list[i], 'frames[$i]');
    final number =
        parseFrameLabel(_str(f, 'number', p)) ??
        _bad('${p}number', 'not a frame number');
    frames.add(
      Frame(
        id: _str(f, 'id', p),
        rollId: id,
        position: _int(f, 'position', p),
        number: number,
        exposure: _exposure(f, p),
        takenAt: _dateOrNull(f, 'takenAt', p),
        utcOffsetMinutes: _intOrNull(f, 'utcOffsetMinutes', p),
        note: _strOrNull(f, 'note', p),
        location: _location(f, p),
        snapshot: _strOrNull(f, 'snapshot', p),
        updatedAt: _date(f, 'updatedAt', p),
      ),
    );
  }
  return (roll, frames);
}

SavedReading readingFromJson(Object? json) {
  final m = _map(json, 'file');
  _header(m, 'grain-reading');
  final body = _map(m['body'], 'body');
  return SavedReading(
    id: _str(m, 'id', ''),
    bodyId: _strOrNull(body, 'id', 'body.'),
    bodyMake: _str(body, 'make', 'body.'),
    bodyModel: _str(body, 'model', 'body.'),
    format: _format(_str(body, 'format', 'body.'), 'body.format'),
    exposure: _exposure(m, ''),
    takenAt: _date(m, 'takenAt', ''),
    utcOffsetMinutes: _int(m, 'utcOffsetMinutes', ''),
    note: _strOrNull(m, 'note', ''),
    location: _location(m, ''),
    snapshot: _strOrNull(m, 'snapshot', ''),
    updatedAt: _date(m, 'updatedAt', ''),
  );
}

// ---- CSV ----

const csvHeader =
    'roll,film,film_type,box_iso,push_stops,exposed_iso,body,frame,date_time,'
    'utc_offset,aperture,shutter,exposure_time_s,iso,lens,focal_mm,mode,'
    'metered_ev,offset_stops,latitude,longitude,note,snapshot';

/// Free text starting with a spreadsheet formula trigger gets a leading `'`.
String _text(String s) => s.isNotEmpty && '=+-@\t\r'.contains(s[0]) ? "'$s" : s;

String _csvField(String s) =>
    s.contains(RegExp('[,"\r\n]')) ? '"${s.replaceAll('"', '""')}"' : s;

String _trim(String s) => s.contains('.')
    ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
    : s;

String _num(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() && v.abs() < 1e9
      ? v.round().toString()
      : v.toString();
}

String _pushStops(int thirds) {
  if (thirds == 0) return '0';
  final s = _trim((thirds / 3).toStringAsFixed(2));
  return thirds > 0 ? '+$s' : s;
}

String _exposureSeconds(double? v) =>
    v == null ? '' : _trim(v.toStringAsPrecision(6));

String rollToCsv(Roll r, List<Frame> frames) {
  final b = StringBuffer('\uFEFF')..write('$csvHeader\r\n');
  for (final f in frames) {
    final e = f.exposure;
    final off = f.utcOffsetMinutes;
    final g = f.location;
    final row = [
      '${r.number}',
      _text(r.filmStock),
      r.filmType.id,
      '${r.boxIso}',
      _pushStops(r.pushThirds),
      '${r.exposedIso}',
      _text(r.bodyName),
      f.label,
      f.takenAt == null ? '' : _local(f.takenAt!, off ?? 0),
      f.takenAt == null || off == null ? '' : offsetLabel(off),
      _num(e.aperture),
      _text(e.shutter ?? ''),
      _exposureSeconds(e.exposureTime),
      e.iso?.toString() ?? '',
      _text(e.lensName ?? ''),
      _num(e.focal),
      e.mode == null ? '' : _modeId(e.mode!),
      e.meteredEv?.toStringAsFixed(1) ?? '',
      e.offset?.toStringAsFixed(2) ?? '',
      g == null ? '' : '${g.latitude}',
      g == null ? '' : '${g.longitude}',
      _text(f.note ?? ''),
      _text(f.snapshot ?? ''),
    ];
    b.write('${row.map(_csvField).join(',')}\r\n');
  }
  return b.toString();
}
