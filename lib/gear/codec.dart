import 'dart:convert';

import 'package:grain/exposure/scales.dart';
import 'package:grain/gear/model.dart';

class GearFormatException implements Exception {
  GearFormatException(this.errors);

  /// Each entry reads 'path: message'.
  final List<String> errors;

  @override
  String toString() => 'GearFormatException: ${errors.join('; ')}';
}

final _idPattern = RegExp(r'^[a-z0-9][a-z0-9.-]{0,63}$');
const _idPatternText = r'^[a-z0-9][a-z0-9.-]{0,63}$';
final _shutterPattern = RegExp(r'^(1/[1-9][0-9]*|[0-9]+(\.[0-9]+)?|B|T)$');

GearDoc parseGearString(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw GearFormatException(['(root): not valid JSON']);
  }
  return parseGear(json);
}

GearDoc parseGear(Object? json) {
  final errors = <String>[];
  final doc = _parseTop(json, errors);
  if (errors.isNotEmpty || doc == null) {
    throw GearFormatException(
      errors.isEmpty ? ['(root): not a Grain gear file'] : errors,
    );
  }
  return doc;
}

GearDoc? _parseTop(Object? json, List<String> errors) {
  if (json is! Map) {
    errors.add('(root): must be a JSON object');
    return null;
  }
  final m = json.cast<String, Object?>();
  final schema = m['schema'];
  if (schema is! int) {
    errors.add('schema: must be the integer 1');
  } else if (schema > 1) {
    errors.add('schema: made by a newer version of Grain (schema $schema)');
  } else if (schema != 1) {
    errors.add('schema: must be the integer 1');
  }
  final type = m['type'];
  switch (type) {
    case 'body':
      return _parseBody(m, '', errors, top: true);
    case 'lens':
      return _parseLens(m, '', errors, top: true);
    case 'kit':
      return _parseKit(m, errors);
    default:
      errors.add('type: must be "body", "lens" or "kit"');
      return null;
  }
}

void _unknownKeys(
  Map<String, Object?> m,
  Set<String> known,
  String prefix,
  List<String> errors,
) {
  for (final k in m.keys) {
    if (!known.contains(k)) errors.add('$prefix$k: unknown key');
  }
}

String? _id(Map<String, Object?> m, String key, String p, List<String> errors) {
  final v = m[key];
  if (v is String && _idPattern.hasMatch(v)) return v;
  errors.add('$p$key: must match $_idPatternText');
  return null;
}

String? _text(
  Map<String, Object?> m,
  String key,
  String p,
  List<String> errors,
) {
  final v = m[key];
  if (v is! String) {
    errors.add('$p$key: must be a string');
    return null;
  }
  final t = v.trim();
  if (t.isEmpty) {
    errors.add('$p$key: must not be empty');
    return null;
  }
  if (t.length > 60) {
    errors.add('$p$key: must be at most 60 characters');
    return null;
  }
  return t;
}

bool _isNum(Object? v) => v is num && v.isFinite;

Body? _parseBody(
  Map<String, Object?> m,
  String p,
  List<String> errors, {
  bool top = false,
}) {
  final before = errors.length;
  _unknownKeys(
    m,
    {
      if (top) 'schema',
      'type',
      'id',
      'make',
      'model',
      'mount',
      'format',
      'frames',
      'shutter',
      'iso',
    },
    p,
    errors,
  );
  final id = _id(m, 'id', p, errors);
  final make = _text(m, 'make', p, errors);
  final model = _text(m, 'model', p, errors);
  final mount = _id(m, 'mount', p, errors);

  FilmFormat? format;
  final f = m['format'];
  if (f is String) format = FilmFormat.byId(f);
  if (format == null) {
    errors.add(
      '${p}format: must be one of ${FilmFormat.values.map((e) => e.id).join(', ')}',
    );
  }

  var frames = format?.defaultFrames ?? 36;
  if (m.containsKey('frames')) {
    final v = m['frames'];
    if (v is int && v >= 1 && v <= 200) {
      frames = v;
    } else {
      errors.add('${p}frames: must be an integer from 1 to 200');
    }
  }

  final shutter = <String>[];
  final s = m['shutter'];
  if (s is! List || s.isEmpty) {
    errors.add('${p}shutter: must be a non-empty list');
  } else {
    final seen = <String>{};
    var timed = false;
    for (var i = 0; i < s.length; i++) {
      final v = s[i];
      if (v is! String || !_validMark(v)) {
        errors.add('${p}shutter[$i]: ${jsonEncode(v)} is not a shutter speed');
        continue;
      }
      if (!seen.add(v)) {
        errors.add('${p}shutter[$i]: "$v" is listed twice');
        continue;
      }
      if (v != 'B' && v != 'T') timed = true;
      shutter.add(v);
    }
    if (!timed) errors.add('${p}shutter: needs at least one timed speed');
  }

  var isoMin = 6;
  var isoMax = 12800;
  if (m.containsKey('iso')) {
    final v = m['iso'];
    if (v is List &&
        v.length == 2 &&
        v[0] is int &&
        v[1] is int &&
        (v[0] as int) >= 6 &&
        (v[0] as int) < (v[1] as int) &&
        (v[1] as int) <= 12800) {
      isoMin = v[0] as int;
      isoMax = v[1] as int;
    } else {
      errors.add('${p}iso: must be [min, max] with 6 <= min < max <= 12800');
    }
  }

  if (errors.length > before ||
      id == null ||
      make == null ||
      model == null ||
      mount == null ||
      format == null) {
    return null;
  }
  return Body(
    id: id,
    make: make,
    model: model,
    mount: mount,
    format: format,
    frames: frames,
    shutter: shutter,
    isoMin: isoMin,
    isoMax: isoMax,
  );
}

bool _validMark(String v) {
  if (!_shutterPattern.hasMatch(v)) return false;
  if (v == 'B' || v == 'T') return true;
  if (v.startsWith('1/')) return true;
  return double.parse(v) > 0;
}

Lens? _parseLens(
  Map<String, Object?> m,
  String p,
  List<String> errors, {
  bool top = false,
}) {
  final before = errors.length;
  _unknownKeys(
    m,
    {
      if (top) 'schema',
      'type',
      'id',
      'make',
      'name',
      'mount',
      'focal',
      'maxAperture',
      'minAperture',
      'apertureStep',
    },
    p,
    errors,
  );
  final id = _id(m, 'id', p, errors);
  final make = _text(m, 'make', p, errors);
  final name = _text(m, 'name', p, errors);
  final mount = _id(m, 'mount', p, errors);

  double? fMin;
  double? fMax;
  final focal = m['focal'];
  if (_isNum(focal) && (focal as num) > 0) {
    fMin = fMax = focal.toDouble();
  } else if (focal is List &&
      focal.length == 2 &&
      _isNum(focal[0]) &&
      _isNum(focal[1])) {
    final a = (focal[0] as num).toDouble();
    final b = (focal[1] as num).toDouble();
    if (a > 0 && a < b) {
      fMin = a;
      fMax = b;
    } else {
      errors.add('${p}focal: must satisfy 0 < min < max');
    }
  } else {
    errors.add('${p}focal: must be a number > 0 or [min, max]');
  }

  List<ApertureAt>? aps;
  final ma = m['maxAperture'];
  final isZoom = fMin != null && fMax != null && fMax > fMin;
  bool inRange(num v) => v >= 0.7 && v <= 64;
  if (_isNum(ma)) {
    if (inRange(ma as num)) {
      if (fMin != null) aps = [ApertureAt(fMin, ma.toDouble())];
    } else {
      errors.add('${p}maxAperture: must be between 0.7 and 64');
    }
  } else if (ma is List) {
    if (fMin != null && !isZoom) {
      errors.add('${p}maxAperture: a prime lens needs a single number');
    } else {
      final list = <ApertureAt>[];
      var ok = true;
      if (ma.length < 2) {
        errors.add('${p}maxAperture: needs at least 2 breakpoints');
        ok = false;
      }
      for (var i = 0; i < ma.length; i++) {
        final e = ma[i];
        if (e is List && e.length == 2 && _isNum(e[0]) && _isNum(e[1])) {
          if (!inRange(e[1] as num)) {
            errors.add(
              '${p}maxAperture[$i]: aperture must be between 0.7 and 64',
            );
            ok = false;
          }
          list.add(
            ApertureAt((e[0] as num).toDouble(), (e[1] as num).toDouble()),
          );
        } else {
          errors.add('${p}maxAperture[$i]: must be [focal, aperture]');
          ok = false;
        }
      }
      if (ok && fMin != null && fMax != null) {
        for (var i = 1; i < list.length; i++) {
          if (list[i].focal <= list[i - 1].focal) {
            errors.add('${p}maxAperture: focals must be strictly ascending');
            ok = false;
            break;
          }
        }
        if (list.first.focal != fMin) {
          errors.add('${p}maxAperture: first breakpoint must be at focal min');
          ok = false;
        }
        if (list.last.focal != fMax) {
          errors.add('${p}maxAperture: last breakpoint must be at focal max');
          ok = false;
        }
      }
      if (ok) aps = list;
    }
  } else {
    errors.add(
      '${p}maxAperture: must be a number${isZoom ? ' or a list of [focal, aperture]' : ''}',
    );
  }

  double? minAp;
  final mi = m['minAperture'];
  if (!_isNum(mi)) {
    errors.add('${p}minAperture: must be a number');
  } else if ((mi as num) > 64) {
    errors.add('${p}minAperture: must be at most 64');
  } else {
    minAp = mi.toDouble();
    if (aps != null && aps.any((a) => minAp! <= a.aperture)) {
      errors.add('${p}minAperture: must be greater than every maxAperture');
      minAp = null;
    }
  }

  StepSize? step;
  final st = m['apertureStep'];
  if (st is String) {
    for (final s in StepSize.values) {
      if (s.name == st) step = s;
    }
  }
  if (step == null) {
    errors.add('${p}apertureStep: must be "full", "half" or "third"');
  }

  if (errors.length > before ||
      id == null ||
      make == null ||
      name == null ||
      mount == null ||
      fMin == null ||
      fMax == null ||
      aps == null ||
      minAp == null ||
      step == null) {
    return null;
  }
  return Lens(
    id: id,
    make: make,
    name: name,
    mount: mount,
    focalMin: fMin,
    focalMax: fMax,
    maxAperture: aps,
    minAperture: minAp,
    apertureStep: step,
  );
}

Kit? _parseKit(Map<String, Object?> m, List<String> errors) {
  final before = errors.length;
  _unknownKeys(m, {'schema', 'type', 'body', 'lenses'}, '', errors);

  Body? body;
  final b = m['body'];
  if (b is Map) {
    final bm = b.cast<String, Object?>();
    if (bm['type'] != 'body') errors.add('body.type: must be "body"');
    body = _parseBody(bm, 'body.', errors);
  } else {
    errors.add('body: must be an object');
  }

  final lenses = <Lens>[];
  final l = m['lenses'];
  if (l is! List || l.isEmpty || l.length > 20) {
    errors.add('lenses: must be a list of 1 to 20 lenses');
  } else {
    for (var i = 0; i < l.length; i++) {
      final e = l[i];
      if (e is! Map) {
        errors.add('lenses[$i]: must be an object');
        continue;
      }
      final em = e.cast<String, Object?>();
      if (em['type'] != 'lens') errors.add('lenses[$i].type: must be "lens"');
      final lens = _parseLens(em, 'lenses[$i].', errors);
      if (lens != null) {
        if (body != null && lens.mount != body.mount) {
          errors.add('lenses[$i].mount: does not fit ${body.mount}');
        } else {
          lenses.add(lens);
        }
      }
    }
  }
  if (errors.length > before || body == null) return null;
  return Kit(body, lenses);
}

// ---------------------------------------------------------------- encoding

Object _n(double v) => v == v.roundToDouble() ? v.toInt() : v;

Map<String, Object?> _bodyJson(
  Body b, {
  required bool compact,
  required bool top,
}) {
  return {
    if (top) 'schema': 1,
    'type': 'body',
    'id': b.id,
    'make': b.make,
    'model': b.model,
    'mount': b.mount,
    'format': b.format.id,
    if (!compact || b.frames != b.format.defaultFrames) 'frames': b.frames,
    'shutter': List<String>.of(b.shutter),
    if (!compact || b.isoMin != 6 || b.isoMax != 12800)
      'iso': [b.isoMin, b.isoMax],
  };
}

Map<String, Object?> _lensJson(Lens l, {required bool top}) {
  return {
    if (top) 'schema': 1,
    'type': 'lens',
    'id': l.id,
    'make': l.make,
    'name': l.name,
    'mount': l.mount,
    'focal': l.isZoom ? [_n(l.focalMin), _n(l.focalMax)] : _n(l.focalMin),
    'maxAperture': l.maxAperture.length == 1
        ? _n(l.maxAperture.first.aperture)
        : [
            for (final a in l.maxAperture) [_n(a.focal), _n(a.aperture)],
          ],
    'minAperture': _n(l.minAperture),
    'apertureStep': l.apertureStep.name,
  };
}

Map<String, Object?> gearToJson(GearDoc doc, {bool compact = false}) {
  return switch (doc) {
    Body b => _bodyJson(b, compact: compact, top: true),
    Lens l => _lensJson(l, top: true),
    Kit k => {
      'schema': 1,
      'type': 'kit',
      'body': _bodyJson(k.body, compact: compact, top: false),
      'lenses': [for (final l in k.lenses) _lensJson(l, top: false)],
    },
  };
}

String encodePretty(GearDoc doc) =>
    '${const JsonEncoder.withIndent('  ').convert(gearToJson(doc))}\n';

String encodeCompact(GearDoc doc) => jsonEncode(gearToJson(doc, compact: true));

// ---------------------------------------------------------------------- QR

enum QrEc { m, l }

class QrPayload {
  const QrPayload(this.data, this.ec);
  final String data;
  final QrEc ec;
}

QrEc? qrLevelForBytes(int n) {
  if (n <= 2331) return QrEc.m;
  if (n <= 2953) return QrEc.l;
  return null;
}

QrPayload? qrPayloadFor(GearDoc doc) {
  final data = encodeCompact(doc);
  final ec = qrLevelForBytes(utf8.encode(data).length);
  return ec == null ? null : QrPayload(data, ec);
}
