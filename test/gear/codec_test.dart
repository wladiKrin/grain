import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/gear/codec.dart';
import 'package:grain/gear/model.dart';

const a1 =
    '{"schema":1,"type":"body","id":"canon-a1","make":"Canon","model":"A-1","mount":"canon-fd","format":"135",'
    '"shutter":["1/1000","1/500","1/250","1/125","1/60","1/30","1/15","1/8","1/4","1/2","1","2","4","8","15","30","B"]}';

Map<String, Object?> zoomJson() => {
  'schema': 1,
  'type': 'lens',
  'id': 'canon-fd-35-70-3.5-4.5',
  'make': 'Canon',
  'name': 'FD 35-70mm f/3.5-4.5',
  'mount': 'canon-fd',
  'focal': [35, 70],
  'maxAperture': [
    [35, 3.5],
    [70, 4.5],
  ],
  'minAperture': 22,
  'apertureStep': 'half',
};

Map<String, Object?> primeJson() => {
  'schema': 1,
  'type': 'lens',
  'id': 'canon-fd-50-1.8',
  'make': 'Canon',
  'name': 'FD 50mm f/1.8',
  'mount': 'canon-fd',
  'focal': 50,
  'maxAperture': 1.8,
  'minAperture': 22,
  'apertureStep': 'half',
};

List<String> _errors(Object? m) {
  try {
    parseGear(m);
  } on GearFormatException catch (e) {
    return e.errors;
  }
  fail('expected GearFormatException');
}

Map<String, Object?> kitJson({Map<String, Object?>? lens}) {
  final l = Map<String, Object?>.of(lens ?? primeJson())..remove('schema');
  final b = (parseGearString(a1) as Body);
  final bj = Map<String, Object?>.of(gearToJson(b))..remove('schema');
  return {
    'schema': 1,
    'type': 'kit',
    'body': bj,
    'lenses': [l],
  };
}

void main() {
  test('parses the Canon A-1 and fills defaults', () {
    final b = parseGearString(a1) as Body;
    expect(b.displayName, 'Canon A-1');
    expect(b.frames, 36);
    expect(b.isoMin, 6);
    expect(b.isoMax, 12800);
    expect(b.hasBulb, isTrue);
    expect(b.format, FilmFormat.f135);
  });

  test('compact encoding of the A-1 is exactly the minimal form', () {
    expect(encodeCompact(parseGearString(a1)), a1);
  });

  test('pretty encoding is indented, newline-terminated, writes defaults', () {
    final s = encodePretty(parseGearString(a1));
    expect(s.endsWith('}\n'), isTrue);
    expect(s, contains('\n  "frames": 36,'));
    expect(s, contains('"iso": [\n    6,\n    12800\n  ]'));
  });

  test('pretty → parse round-trips body, zoom lens and kit', () {
    for (final d in [
      parseGearString(a1),
      parseGear(zoomJson()),
      parseGear(primeJson()),
      parseGear(kitJson()),
    ]) {
      final again = parseGearString(encodePretty(d));
      if (d is Kit) {
        expect(gearToJson(again), gearToJson(d));
        expect(again, isA<Kit>());
      } else {
        expect(again, d);
      }
    }
    expect(gearToJson(parseGear(primeJson())), primeJson());
    expect(encodeCompact(parseGear(zoomJson())), contains('"focal":[35,70]'));
  });

  test('zoom with varying aperture parses breakpoints', () {
    final l = parseGear(zoomJson()) as Lens;
    expect(l.isZoom, isTrue);
    expect(l.maxAperture.last, const ApertureAt(70, 4.5));
    expect(l.shortName, 'FD 35-70/3.5-4.5');
    expect(l.apertureStep, StepSize.half);
  });

  test('zoom with constant aperture parses and re-encodes as a number', () {
    final j = zoomJson()..['maxAperture'] = 4;
    final l = parseGear(j) as Lens;
    expect(l.maxAperture, [const ApertureAt(35, 4)]);
    expect(gearToJson(l)['maxAperture'], 4);
  });

  test('collects every error with its path', () {
    final e = _errors({
      'schema': 1,
      'type': 'body',
      'id': 'Canon A1',
      'make': '',
      'model': 'A-1',
      'mount': 'canon-fd',
      'format': '135',
      'shutter': ['B', '1/1OOO'],
      'colour': 'black',
    });
    expect(
      e,
      containsAll([
        'id: must match ^[a-z0-9][a-z0-9.-]{0,63}\$',
        'make: must not be empty',
        'shutter[1]: "1/1OOO" is not a shutter speed',
        'shutter: needs at least one timed speed',
        'colour: unknown key',
      ]),
    );
  });

  test('body field rules', () {
    final base = jsonOf(a1);
    expect(
      _errors({...base, 'frames': 0}),
      contains('frames: must be an integer from 1 to 200'),
    );
    expect(
      _errors({
        ...base,
        'iso': [100, 100],
      }),
      contains('iso: must be [min, max] with 6 <= min < max <= 12800'),
    );
    expect(_errors({...base, 'format': '110'}).single, startsWith('format:'));
    expect(
      _errors({
        ...base,
        'shutter': ['1/60', '1/60'],
      }),
      contains('shutter[1]: "1/60" is listed twice'),
    );
    final ok = parseGear({
      ...base,
      'frames': 24,
      'iso': [25, 3200],
    }) as Body;
    expect(ok.frames, 24);
    expect(ok.isoMin, 25);
    expect(encodeCompact(ok), contains('"frames":24'));
    expect(encodeCompact(ok), contains('"iso":[25,3200]'));
  });

  test('foreign and future input is rejected with a readable error', () {
    expect(
      _errors({'schema': 2, 'type': 'body'}),
      contains('schema: made by a newer version of Grain (schema 2)'),
    );
    for (final text in [
      'https://example.org',
      '[1,2]',
      '{"type":"body"}',
      '',
    ]) {
      expect(
        () => parseGearString(text),
        throwsA(isA<GearFormatException>()),
        reason: text,
      );
    }
  });

  test('kit lenses must fit the body mount', () {
    final nikon = {...primeJson(), 'mount': 'nikon-f'};
    final e = _errors(kitJson(lens: nikon));
    expect(e, contains('lenses[0].mount: does not fit canon-fd'));
  });

  test('kit nested objects must not carry schema', () {
    final j = kitJson();
    (j['body']! as Map<String, Object?>)['schema'] = 1;
    expect(_errors(j), contains('body.schema: unknown key'));
  });

  test('lens rules', () {
    expect(
      _errors({
        ...primeJson(),
        'maxAperture': [
          [50, 1.8],
          [50, 2],
        ],
      }),
      ['maxAperture: a prime lens needs a single number'],
    );
    expect(_errors({...primeJson(), 'minAperture': 1.4}), [
      'minAperture: must be greater than every maxAperture',
    ]);
    expect(
      _errors({
        ...zoomJson(),
        'maxAperture': [
          [35, 3.5],
          [60, 4.5],
        ],
      }),
      ['maxAperture: last breakpoint must be at focal max'],
    );
    expect(
      _errors({
        ...primeJson(),
        'focal': [70, 35],
      }),
      contains('focal: must satisfy 0 < min < max'),
    );
    expect(
      _errors({...primeJson(), 'minAperture': 70}),
      contains('minAperture: must be at most 64'),
    );
    expect(
      _errors({...primeJson(), 'maxAperture': 0.5}),
      contains('maxAperture: must be between 0.7 and 64'),
    );
  });

  test('QR level by byte count', () {
    expect(qrLevelForBytes(2331), QrEc.m);
    expect(qrLevelForBytes(2332), QrEc.l);
    expect(qrLevelForBytes(2953), QrEc.l);
    expect(qrLevelForBytes(2954), isNull);
    expect(qrPayloadFor(parseGearString(a1))!.ec, QrEc.m);
    expect(qrPayloadFor(parseGearString(a1))!.data, a1);
  });
}

Map<String, Object?> jsonOf(String s) => Map<String, Object?>.of(
  (parseGearString(s) is Body)
      ? gearToJson(parseGearString(s), compact: true)
      : {},
);
