import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/solver.dart';
import 'package:grain/metering/reading.dart';

MeterStats stats({
  int exp = 1000000,
  int iso = 100,
  double frame = .18,
  double crop = .18,
  double spot = .18,
  double aperture = 1.68,
}) => MeterStats.fromMap({
  'exposureNs': exp,
  'sensitivity': iso,
  'boost': 100,
  'aperture': aperture,
  'minExposureNs': 10000,
  'maxExposureNs': 500000000,
  'minIso': 50,
  'maxIso': 6400,
  'frameLuma': frame,
  'cropLuma': crop,
  'spotLuma': spot,
  'histogram': List<Object?>.filled(64, 0),
});

void main() {
  test('apertureAssumed is read, absent means false', () {
    expect(stats().apertureAssumed, isFalse);
    final m = {
      'exposureNs': 1000000,
      'sensitivity': 100,
      'aperture': 1.8,
      'minExposureNs': 1,
      'maxExposureNs': 2,
      'minIso': 50,
      'maxIso': 6400,
      'frameLuma': .18,
      'cropLuma': .18,
      'spotLuma': .18,
      'histogram': <Object?>[1],
    };
    expect(MeterStats.fromMap(m).apertureAssumed, isFalse);
    expect(
      MeterStats.fromMap({...m, 'apertureAssumed': true}).apertureAssumed,
      isTrue,
    );
  });
  test('zoom, camera and AE state are read; absent means unknown', () {
    expect(stats().zoom, 1);
    expect(stats().camera, isNull);
    expect(stats().aeState, isNull);
    final m = {
      'exposureNs': 1000000,
      'sensitivity': 100,
      'aperture': 2.8,
      'minExposureNs': 1,
      'maxExposureNs': 2,
      'minIso': 50,
      'maxIso': 6400,
      'frameLuma': .18,
      'cropLuma': .18,
      'spotLuma': .18,
      'histogram': <Object?>[1],
      'zoom': 4.2,
      'camera': 'tele',
      'aeState': 'converged',
    };
    final s = MeterStats.fromMap(m);
    expect(s.zoom, 4.2);
    expect(s.camera, 'tele');
    expect(s.aeState, 'converged');
  });

  test('AE result to EV100', () {
    expect(
      readingFrom(stats(), area: MeterArea.average)!.ev100,
      closeTo(11.46, 0.01),
    );
  });
  test('spot twice as bright as frame reads +1 EV', () {
    final r = readingFrom(stats(spot: .36), area: MeterArea.spot)!;
    expect(r.ev100, closeTo(12.46, 0.01));
  });
  test('calibration is added', () {
    expect(
      readingFrom(stats(), area: MeterArea.average, calibration: -2 / 3)!.ev100,
      closeTo(10.79, 0.01),
    );
  });
  test('black region at AE limits is under-range, never -inf/NaN', () {
    final r = readingFrom(
      stats(exp: 500000000, iso: 6400, crop: 0),
      area: MeterArea.average,
    )!;
    expect(r.flag, RangeFlag.under);
    expect(r.ev100.isFinite, isTrue);
  });
  test('blown region at AE minimum is over-range', () {
    final r = readingFrom(
      stats(exp: 10000, iso: 50, crop: .95),
      area: MeterArea.average,
    )!;
    expect(r.flag, RangeFlag.over);
  });
  test(
    'missing key throws FormatException naming it; boost defaults to 100',
    () {
      final m = <Object?, Object?>{
        'exposureNs': 1000000,
        'sensitivity': 100,
        'aperture': 1.68,
        'minExposureNs': 10000,
        'maxExposureNs': 500000000,
        'minIso': 50,
        'maxIso': 6400,
        'frameLuma': .18,
        'cropLuma': .18,
        'spotLuma': .18,
        'histogram': <Object?>[1, 2],
      };
      expect(MeterStats.fromMap(m).boost, 100);
      m.remove('spotLuma');
      expect(
        () => MeterStats.fromMap(m),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('spotLuma'),
          ),
        ),
      );
    },
  );
  test('degenerate AE metadata yields no reading', () {
    expect(readingFrom(stats(aperture: 0), area: MeterArea.average), isNull);
    expect(readingFrom(stats(aperture: -1), area: MeterArea.average), isNull);
    expect(readingFrom(stats(exp: 0), area: MeterArea.average), isNull);
    expect(readingFrom(stats(exp: -5), area: MeterArea.average), isNull);
    expect(readingFrom(stats(iso: 0), area: MeterArea.average), isNull);
  });
  test('non-finite lumas yield no reading', () {
    for (final bad in [double.nan, double.infinity, double.negativeInfinity]) {
      expect(readingFrom(stats(frame: bad), area: MeterArea.average), isNull);
      expect(readingFrom(stats(crop: bad), area: MeterArea.average), isNull);
      expect(readingFrom(stats(spot: bad), area: MeterArea.spot), isNull);
      expect(
        readingFrom(stats(aperture: bad), area: MeterArea.average),
        isNull,
      );
    }
  });
}
