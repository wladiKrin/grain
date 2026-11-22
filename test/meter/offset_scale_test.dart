import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/stops.dart';

void main() {
  test('formatStops renders thirds with fraction glyphs', () {
    expect(formatStops(0), '0');
    expect(formatStops(-0.0), '0');
    expect(formatStops(1 / 3), '+⅓');
    expect(formatStops(2 / 3), '+⅔');
    expect(formatStops(1), '+1');
    expect(formatStops(5 / 3), '+1⅔');
    expect(formatStops(-4 / 3), '−1⅓');
    expect(formatStops(-2 / 3), '−⅔');
    expect(formatStops(-3), '−3');
  });

  test('formatStops rounds to the nearest third', () {
    expect(formatStops(0.34), '+⅓');
    expect(formatStops(0.1), '0');
    expect(formatStops(1.0000001), '+1');
    expect(formatStops(-1.32), '−1⅓');
  });

  group('formatHalfStops', () {
    test('half stops', () {
      expect([0, 1, -1, 6, -5, 7].map(formatHalfStops), [
        '0',
        '+½',
        '−½',
        '+3',
        '−2½',
        '+3½',
      ]);
    });
    test('latitude limits', () {
      expect(formatHalfStops(latitudeUnderHalvesMin), '−5');
      expect(formatHalfStops(latitudeOverHalvesMax), '+6');
    });
  });
}
