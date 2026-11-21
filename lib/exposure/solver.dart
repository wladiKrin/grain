import 'dart:math' as math;

import 'scales.dart';

double _log2(double x) => math.log(x) / math.ln2;

/// Scene EV (referenced to ISO 100) expressed at the given [iso].
double evAtIso(double ev100, double iso) => ev100 + _log2(iso / 100);

/// [over]: scene too bright for the scale (would need a faster shutter or
/// smaller aperture than available). [under]: too dark.
enum RangeFlag { ok, over, under }

class Solved {
  const Solved(this.index, this.flag);

  final int index;
  final RangeFlag flag;

  @override
  String toString() => 'Solved($index, $flag)';
}

/// Half of the log2 step between the end value and its neighbour; 1/6 stop
/// for a single-element scale.
double _halfStep(List<ScaleValue> scale, {required bool first}) {
  if (scale.length < 2) return 1 / 6;
  final a = first ? scale[0] : scale[scale.length - 2];
  final b = first ? scale[1] : scale[scale.length - 1];
  return _log2(b.value / a.value).abs() / 2;
}

/// Snaps [exact] to [scale] (ascending or descending by value). [excess] is
/// how many stops [exact] lies beyond the scale's first end (positive) or
/// last end (negative direction handled by [firstIsOver]).
Solved _snap(List<ScaleValue> scale, double exact, {required bool firstIsOver}) {
  final first = scale.first.value;
  final last = scale.last.value;
  final ascending = last >= first;
  final lowEnd = ascending ? 0 : scale.length - 1;
  final highEnd = ascending ? scale.length - 1 : 0;
  final lo = scale[lowEnd].value;
  final hi = scale[highEnd].value;

  RangeFlag low() => firstIsOver == ascending ? RangeFlag.over : RangeFlag.under;
  RangeFlag high() => low() == RangeFlag.over ? RangeFlag.under : RangeFlag.over;

  if (exact < lo &&
      _log2(lo / exact) > _halfStep(scale, first: lowEnd == 0)) {
    return Solved(lowEnd, low());
  }
  if (exact > hi &&
      _log2(exact / hi) > _halfStep(scale, first: highEnd == 0)) {
    return Solved(highEnd, high());
  }
  return Solved(nearestIndex(scale, exact), RangeFlag.ok);
}

/// Exact `t = N² / 2^EV_S`, snapped to [shutters] (fastest first).
Solved solveShutter({
  required double ev100,
  required double iso,
  required double aperture,
  required List<ScaleValue> shutters,
}) {
  final t = aperture * aperture / math.pow(2, evAtIso(ev100, iso));
  // Small t (faster than the first value) means too bright.
  return _snap(shutters, t, firstIsOver: true);
}

/// Exact `N = sqrt(t · 2^EV_S)`, snapped to [apertures] (smallest f-number
/// first).
Solved solveAperture({
  required double ev100,
  required double iso,
  required double shutter,
  required List<ScaleValue> apertures,
}) {
  final n = math.sqrt(shutter * math.pow(2, evAtIso(ev100, iso)));
  // Large f-number beyond the last value means too bright.
  return _snap(apertures, n, firstIsOver: false);
}

/// Stops of exposure error for a manual setting, rounded to [step];
/// positive = overexposed.
double manualOffset({
  required double ev100,
  required double iso,
  required double aperture,
  required double shutter,
  double step = 1 / 3,
}) {
  final raw =
      _log2(shutter / (aperture * aperture)) + evAtIso(ev100, iso);
  final v = (raw / step).round() * step;
  return v == 0 ? 0.0 : v; // normalise -0.0
}
