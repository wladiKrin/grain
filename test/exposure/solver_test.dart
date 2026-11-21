import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/exposure/solver.dart';

void main() {
  final shutters = shutterScale(step: StepSize.third);
  final apertures = apertureScale(step: StepSize.third);

  test('evAtIso shifts by log2(iso/100)', () {
    expect(evAtIso(12, 400), closeTo(14, 1e-9));
    expect(evAtIso(12, 100), closeTo(12, 1e-9));
  });

  test('sunny 16: EV15 ISO100 f/16 → 1/125', () {
    final r = solveShutter(ev100: 15, iso: 100, aperture: 16, shutters: shutters)!;
    expect(shutters[r.index].label, '1/125');
    expect(r.flag, RangeFlag.ok);
  });
  test('ISO 400 shifts two stops: EV12 f/4 is 1/250 at ISO 100, 1/1000 at 400',
      () {
    final base =
        solveShutter(ev100: 12, iso: 100, aperture: 4, shutters: shutters)!;
    expect(shutters[base.index].label, '1/250');
    final r = solveShutter(ev100: 12, iso: 400, aperture: 4, shutters: shutters)!;
    expect(shutters[r.index].label, '1/1000');
  });
  test('shutter priority: EV15 ISO100 1/125 → f/16', () {
    final r = solveAperture(
        ev100: 15, iso: 100, shutter: 1 / 128, apertures: apertures)!;
    expect(apertures[r.index].label, '16');
    expect(r.flag, RangeFlag.ok);
  });
  test('too bright for the fastest shutter → over, clamped', () {
    final r = solveShutter(ev100: 20, iso: 3200, aperture: 1, shutters: shutters)!;
    expect(r.index, 0);
    expect(r.flag, RangeFlag.over);
  });
  test('too dark for 30 s → under, clamped', () {
    final r = solveShutter(ev100: -8, iso: 25, aperture: 64, shutters: shutters)!;
    expect(r.index, shutters.length - 1);
    expect(r.flag, RangeFlag.under);
  });
  test('aperture: too bright → over at f/64, too dark → under at f/1', () {
    final over = solveAperture(
        ev100: 22, iso: 100, shutter: 1 / 8, apertures: apertures)!;
    expect(over.index, apertures.length - 1);
    expect(over.flag, RangeFlag.over);
    final under = solveAperture(
        ev100: -4, iso: 100, shutter: 1 / 8000, apertures: apertures)!;
    expect(under.index, 0);
    expect(under.flag, RangeFlag.under);
  });
  test('slightly beyond the end (within half a step) stays ok', () {
    // EV 13.06 at f/1 needs ~1/8400 s: ~0.07 stop past the 1/8000 end.
    final r = solveShutter(
        ev100: 13.06, iso: 100, aperture: 1, shutters: shutters)!;
    expect(r.index, 0);
    expect(r.flag, RangeFlag.ok);
  });
  test('single-element scale does not throw', () {
    final one = [shutters.first];
    final r = solveShutter(ev100: 0, iso: 100, aperture: 1, shutters: one)!;
    expect(r.index, 0);
  });
  test('manual offset: one stop too slow reads +1', () {
    expect(manualOffset(ev100: 15, iso: 100, aperture: 16, shutter: 1 / 64),
        closeTo(1, 1e-9));
    expect(manualOffset(ev100: 15, iso: 100, aperture: 16, shutter: 1 / 128),
        closeTo(0, 1e-9));
  });
  test('manual offset: exact match is exactly 0 and underexposure negative', () {
    final z = manualOffset(ev100: 15, iso: 100, aperture: 16, shutter: 1 / 128);
    expect(z, 0.0);
    expect(z!.isNegative, isFalse);
    expect(manualOffset(ev100: 15, iso: 100, aperture: 16, shutter: 1 / 256),
        closeTo(-1, 1e-9));
  });
  test('non-finite EV never throws: solvers and offset return null', () {
    for (final ev in [double.nan, double.infinity, double.negativeInfinity]) {
      expect(solveShutter(ev100: ev, iso: 100, aperture: 16, shutters: shutters),
          isNull);
      expect(
          solveAperture(ev100: ev, iso: 100, shutter: 1 / 125, apertures: apertures),
          isNull);
      expect(manualOffset(ev100: ev, iso: 100, aperture: 16, shutter: 1 / 125),
          isNull);
    }
  });

  test('absurd EV gives no solution instead of throwing', () {
    expect(solveShutter(ev100: 2000, iso: 100, aperture: 2, shutters: shutters), isNull);
  });
}
