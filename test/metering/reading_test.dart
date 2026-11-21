import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/solver.dart';
import 'package:grain/metering/reading.dart';

MeterStats stats({int exp = 1000000, int iso = 100, double frame = .18, double crop = .18, double spot = .18}) =>
    MeterStats.fromMap({'exposureNs': exp, 'sensitivity': iso, 'boost': 100, 'aperture': 1.68,
      'minExposureNs': 10000, 'maxExposureNs': 500000000, 'minIso': 50, 'maxIso': 6400,
      'frameLuma': frame, 'cropLuma': crop, 'spotLuma': spot, 'histogram': List<Object?>.filled(64, 0)});

void main() {
  test('AE result to EV100', () {
    expect(readingFrom(stats(), area: MeterArea.average).ev100, closeTo(11.46, 0.01));
  });
  test('spot twice as bright as frame reads +1 EV', () {
    final r = readingFrom(stats(spot: .36), area: MeterArea.spot);
    expect(r.ev100, closeTo(12.46, 0.01));
  });
  test('calibration is added', () {
    expect(readingFrom(stats(), area: MeterArea.average, calibration: -2 / 3).ev100, closeTo(10.79, 0.01));
  });
  test('black region at AE limits is under-range, never -inf/NaN', () {
    final r = readingFrom(stats(exp: 500000000, iso: 6400, crop: 0), area: MeterArea.average);
    expect(r.flag, RangeFlag.under);
    expect(r.ev100.isFinite, isTrue);
  });
  test('blown region at AE minimum is over-range', () {
    final r = readingFrom(stats(exp: 10000, iso: 50, crop: .95), area: MeterArea.average);
    expect(r.flag, RangeFlag.over);
  });
  test('missing key throws FormatException naming it; boost defaults to 100', () {
    final m = <Object?, Object?>{'exposureNs': 1000000, 'sensitivity': 100, 'aperture': 1.68,
      'minExposureNs': 10000, 'maxExposureNs': 500000000, 'minIso': 50, 'maxIso': 6400,
      'frameLuma': .18, 'cropLuma': .18, 'spotLuma': .18, 'histogram': <Object?>[1, 2]};
    expect(MeterStats.fromMap(m).boost, 100);
    m.remove('spotLuma');
    expect(() => MeterStats.fromMap(m),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('spotLuma'))));
  });
}
