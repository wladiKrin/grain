import 'dart:math' as math;

import 'package:grain/exposure/scales.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/metering/fov.dart';

/// The selected body, lens and focal length. `body == null` is "No camera"
/// (and [lens] must then be null).
class GearSetup {
  const GearSetup({this.body, this.lens, this.focal = 50});

  final Body? body;
  final Lens? lens;
  final double focal;

  @override
  bool operator ==(Object other) =>
      other is GearSetup &&
      other.body == body &&
      other.lens == lens &&
      other.focal == focal;

  @override
  int get hashCode => Object.hash(body, lens, focal);
}

class GearScales {
  const GearScales({
    required this.apertures,
    required this.shutters,
    required this.isos,
    required this.focals,
    required this.hasBulb,
    required this.format,
  });

  final List<ScaleValue> apertures, shutters, isos, focals;
  final bool hasBulb;
  final FilmFormat format;

  GearScales withIsos(List<ScaleValue> isos) => GearScales(
    apertures: apertures,
    shutters: shutters,
    isos: isos,
    focals: focals,
    hasBulb: hasBulb,
    format: format,
  );
}

double _log2(double x) => math.log(x) / math.ln2;

/// Widest aperture of [lens] at [focal], interpolated in log-focal / stops
/// between breakpoints and snapped to the lens's own aperture grid.
double effectiveMaxAperture(Lens lens, double focal) {
  final bp = lens.maxAperture;
  if (bp.length == 1) return bp.first.aperture;
  final f = focal.clamp(bp.first.focal, bp.last.focal).toDouble();
  for (final p in bp) {
    if ((p.focal - f).abs() < 1e-6) return p.aperture;
  }
  var i = 0;
  while (i < bp.length - 2 && bp[i + 1].focal < f) {
    i++;
  }
  final a = bp[i], b = bp[i + 1];
  final t = math.log(f / a.focal) / math.log(b.focal / a.focal);
  final sa = _log2(a.aperture * a.aperture);
  final sb = _log2(b.aperture * b.aperture);
  final exact = math.sqrt(math.pow(2, sa + t * (sb - sa)));
  final candidates = <double>[
    for (final v in apertureScale(step: lens.apertureStep)) v.value,
    for (final p in bp) p.aperture,
  ]..sort();
  for (final c in candidates) {
    if (2 * _log2(c / exact) >= -0.05) return c;
  }
  return candidates.last;
}

List<ScaleValue> focalValuesFor(Lens zoom) => [
  ScaleValue(_whole(zoom.focalMin), zoom.focalMin, false),
  for (final f in focalStops)
    if (f > zoom.focalMin && f < zoom.focalMax)
      ScaleValue('$f', f.toDouble(), false),
  ScaleValue(_whole(zoom.focalMax), zoom.focalMax, false),
];

String _whole(double v) => v.round().toString();

GearScales scalesFor(GearSetup s) {
  final body = s.body, lens = s.lens;
  final List<ScaleValue> focals;
  if (lens == null) {
    focals = [
      for (final f in focalStops) ScaleValue('$f', f.toDouble(), false),
    ];
  } else if (lens.isZoom) {
    focals = focalValuesFor(lens);
  } else {
    focals = [ScaleValue(_whole(lens.focalMin), lens.focalMin, false)];
  }
  return GearScales(
    shutters: body == null
        ? shutterScale(step: StepSize.third)
        : bodyShutterScale(body.shutter),
    apertures: lens == null
        ? apertureScale(step: StepSize.third)
        : apertureScale(
            step: lens.apertureStep,
            min: effectiveMaxAperture(lens, s.focal),
            max: lens.minAperture,
          ),
    isos: body == null
        ? isoScale()
        : isoScale(min: body.isoMin, max: body.isoMax),
    focals: focals,
    hasBulb: body == null ? true : body.hasBulb,
    format: body?.format ?? FilmFormat.f135,
  );
}
