import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';

void main() {
  test('aperture thirds f/1–f/64 has 37 values, full stops flagged', () {
    final s = apertureScale(step: StepSize.third);
    expect(s.length, 37);
    expect(s.first.label, '1');
    expect(s.last.label, '64');
    expect(s.where((v) => v.isFullStop).map((v) => v.label), [
      '1',
      '1.4',
      '2',
      '2.8',
      '4',
      '5.6',
      '8',
      '11',
      '16',
      '22',
      '32',
      '45',
      '64',
    ]);
    expect(s[3].value, closeTo(math.sqrt2, 1e-9)); // exact, not 1.4
  });

  test('shutter thirds 1/8000–30s, fast to slow', () {
    final s = shutterScale(step: StepSize.third);
    expect(s.first.label, '1/8000');
    expect(s.last.label, '30"');
    expect(
      s.firstWhere((v) => v.label == '1/125').value,
      closeTo(1 / 128, 1e-9),
    );
    expect(s.where((v) => v.isFullStop).map((v) => v.label).toList(), [
      '1/8000',
      '1/4000',
      '1/2000',
      '1/1000',
      '1/500',
      '1/250',
      '1/125',
      '1/60',
      '1/30',
      '1/15',
      '1/8',
      '1/4',
      '1/2',
      '1"',
      '2"',
      '4"',
      '8"',
      '15"',
      '30"',
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
      '6',
      '12',
      '25',
      '50',
      '100',
      '200',
      '400',
      '800',
      '1600',
      '3200',
      '6400',
      '12800',
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
    expect(s.map((v) => v.label).toList(), [
      '1.8',
      '2',
      '2.2',
      '2.5',
      '2.8',
      '3.2',
      '3.5',
    ]);
  });

  test('off-grid sub-second shutter limit is labelled in seconds', () {
    final s = shutterScale(
      step: StepSize.third,
      fastest: 1 / 1000,
      slowest: .7,
    );
    expect(s.last.label, '0.7"');
    expect(s.last.value, .7);
    expect(
      s[s.length - 2].label,
      '1/2',
    ); // 0.6" lies < 1/4 stop from 0.7 → dropped
  });
  test('off-grid aperture limit drops a grid value closer than 1/4 stop', () {
    expect(
      apertureScale(
        step: StepSize.third,
        min: 1.7,
        max: 22,
      ).take(3).map((v) => v.label),
      ['1.7', '2', '2.2'],
    );
    expect(
      apertureScale(
        step: StepSize.half,
        min: 4.5,
        max: 22,
      ).take(2).map((v) => v.label),
      ['4.5', '5.6'],
    );
    expect(
      apertureScale(
        step: StepSize.full,
        min: 1.8,
        max: 22,
      ).take(3).map((v) => v.label),
      ['1.8', '2', '2.8'],
    );
  });
  test('limit within 0.05 stop keeps the grid value', () {
    final s = apertureScale(step: StepSize.third, min: 1.8);
    expect(s.first.label, '1.8');
    expect(s.first.value, closeTo(math.pow(2, 5 / 6), 1e-9));
  });
  test('ISO and aperture-max extra end values', () {
    final iso = isoScale(
      min: 25,
      max: 3000,
    ); // 2500 (exact 2540) lies 0.24 stop below → dropped
    expect(iso.reversed.take(2).map((v) => v.label), ['3000', '2000']);
    expect(apertureScale(step: StepSize.half, max: 30).last.label, '30');
  });
  test('half-step full stops match the full-stop scale', () {
    expect(
      apertureScale(step: StepSize.half)
          .where((v) => v.isFullStop)
          .map((v) => v.label),
      apertureScale(step: StepSize.full).map((v) => v.label),
    );
  });
  test('nearestIndex rejects empty scales and non-positive values', () {
    expect(() => nearestIndex(const [], 2), throwsArgumentError);
    expect(
      () => nearestIndex(apertureScale(step: StepSize.full), 0),
      throwsArgumentError,
    );
  });
  test('body shutter list: Canon A-1', () {
    final s = bodyShutterScale([
      '1/1000',
      '1/500',
      '1/250',
      '1/125',
      '1/60',
      '1/30',
      '1/15',
      '1/8',
      '1/4',
      '1/2',
      '1',
      '2',
      '4',
      '8',
      '15',
      '30',
      'B',
    ]);
    expect(s.length, 16);
    expect(s.first.label, '1/1000');
    expect(s.first.value, closeTo(1 / 1024, 1e-12));
    expect(s.last.label, '30"');
    expect(s.last.value, closeTo(32, 1e-9));
    expect(s.every((v) => v.isFullStop), isTrue);
    expect(s.firstWhere((v) => v.label == '15"').value, closeTo(16, 1e-9));
  });
  test('body shutter list: halves and nominal marks', () {
    final s = bodyShutterScale(['1/750', '1/1000', '1/300']);
    expect(s.map((v) => v.label), [
      '1/1000',
      '1/750',
      '1/300',
    ]); // sorted fast → slow
    expect(s[1].isFullStop, isFalse);
    expect(s[2].value, closeTo(1 / 300, 1e-12));
    expect(() => bodyShutterScale(['B']), throwsArgumentError);
    expect(() => bodyShutterScale(['1/1OOO']), throwsArgumentError);
  });
  test('formatSeconds', () {
    expect(formatSeconds(.25), '1/4');
    expect(formatSeconds(2.5), '2.5"');
    expect(formatSeconds(4), '4"');
    expect(formatSeconds(45), '45"');
    expect(formatSeconds(150), '2m 30s');
    expect(formatSeconds(4000), '1h 07m');
  });
}
