import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';

void main() {
  test('aperture thirds f/1–f/64 has 37 values, full stops flagged', () {
    final s = apertureScale(step: StepSize.third);
    expect(s.length, 37);
    expect(s.first.label, '1');
    expect(s.last.label, '64');
    expect(s.where((v) => v.isFullStop).map((v) => v.label),
        ['1', '1.4', '2', '2.8', '4', '5.6', '8', '11', '16', '22', '32', '45', '64']);
    expect(s[3].value, closeTo(math.sqrt2, 1e-9)); // exact, not 1.4
  });

  test('shutter thirds 1/8000–30s, fast to slow', () {
    final s = shutterScale(step: StepSize.third);
    expect(s.first.label, '1/8000');
    expect(s.last.label, '30"');
    expect(s.firstWhere((v) => v.label == '1/125').value, closeTo(1 / 128, 1e-9));
    expect(s.where((v) => v.isFullStop).map((v) => v.label).toList(), [
      '1/8000', '1/4000', '1/2000', '1/1000', '1/500', '1/250', '1/125',
      '1/60', '1/30', '1/15', '1/8', '1/4', '1/2', '1"', '2"', '4"', '8"',
      '15"', '30"',
    ]);
  });

  test('aperture scale respects min/max (lens limits)', () {
    final s = apertureScale(step: StepSize.half, min: 1.8, max: 22);
    expect(s.first.label, '1.8');
    expect(s.first.value, 1.8);
    expect(s.first.isFullStop, isFalse);
    expect(s[1].label, '2');
    expect(s.last.label, '22');
  });

  test('nearestIndex snaps by log distance', () {
    final s = apertureScale(step: StepSize.full);
    expect(s[nearestIndex(s, 3.0)].label, '2.8');
    expect(s[nearestIndex(s, 3.5)].label, '4');
  });

  test('iso thirds 6–12800', () {
    final s = isoScale();
    expect(s.first.label, '6');
    expect(s.last.label, '12800');
    expect(s.where((v) => v.label == '400').single.isFullStop, isTrue);
    expect(s.where((v) => v.isFullStop).map((v) => v.label).toList(), [
      '6', '12', '25', '50', '100', '200', '400', '800', '1600', '3200',
      '6400', '12800',
    ]);
  });

  test('full and half steps', () {
    expect(apertureScale(step: StepSize.half).length, 25);
    expect(shutterScale(step: StepSize.half).length, 37);
    expect(shutterScale(step: StepSize.full).length, 19);
    expect(isoScale(step: StepSize.full).map((v) => v.label).first, '6');
  });

  test('limits within tolerance of the grid reuse the grid value', () {
    final s = apertureScale(step: StepSize.third, min: 1.8, max: 3.5);
    expect(s.map((v) => v.label).toList(), ['1.8', '2', '2.2', '2.5', '2.8', '3.2', '3.5']);
  });
}
