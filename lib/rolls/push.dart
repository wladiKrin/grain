import 'dart:math' as math;

import '../exposure/scales.dart';
import '../exposure/stops.dart';
import 'film_stocks.dart';
import 'model.dart';
import 'numbering.dart';

/// Exposed-at ISO for a [box] speed pushed (+) or pulled (−) by [pushThirds]
/// thirds of a stop, snapped to the nearest ISO scale label; null when
/// outside the scale (6 … 12800, half a third of slack each side).
int? exposedIsoFor(int box, int pushThirds) {
  if (pushThirds == 0) return box;
  final v = box * math.pow(2, pushThirds / 3);
  if (v < 6 * math.pow(2, -1 / 6) || v > 12800 * math.pow(2, 1 / 6)) {
    return null;
  }
  final scale = isoScale();
  return int.parse(scale[nearestIndex(scale, v.toDouble())].label);
}

String pushLabel(int pushThirds) {
  if (pushThirds == 0) return 'Box speed';
  final s = formatStops(pushThirds / 3);
  return pushThirds > 0 ? 'Push $s' : 'Pull $s';
}

String filmLine(Roll r) {
  final base = '${shortFilmName(r.filmStock)} · ${r.boxIso}';
  return r.pushThirds != 0 ? '$base → ${r.exposedIso}' : base;
}

String rollStatus(Roll r, int next) {
  final base = 'Roll ${r.number} · frame ${frameLabel(next)}/${r.size}';
  final over = overrun(r, next);
  return over > 0 ? '$base +$over' : base;
}

/// Screen-reader label of an ISO value; [differs] when it is not the roll's.
String isoSemantics(String iso, {bool differs = false}) =>
    differs ? 'ISO $iso, differs from the roll' : 'ISO $iso';
