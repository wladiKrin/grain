import 'dart:math' as math;

import '../exposure/solver.dart';

double _log2(double x) => math.log(x) / math.ln2;

const double _lumaFloor = 1e-4;

/// One camera frame's AE metadata and linear-luma statistics.
class MeterStats {
  const MeterStats({
    required this.exposureNs,
    required this.sensitivity,
    required this.boost,
    required this.aperture,
    required this.minExposureNs,
    required this.maxExposureNs,
    required this.minIso,
    required this.maxIso,
    required this.frameLuma,
    required this.cropLuma,
    required this.spotLuma,
    required this.histogram,
  });

  factory MeterStats.fromMap(Map<Object?, Object?> m) {
    Object req(String k) {
      final v = m[k];
      if (v == null) throw FormatException('Missing required key: $k', k);
      return v;
    }

    double d(String k) => (req(k) as num).toDouble();
    int i(String k) => (req(k) as num).toInt();

    return MeterStats(
      exposureNs: i('exposureNs'),
      sensitivity: i('sensitivity'),
      boost: m['boost'] == null ? 100 : (m['boost'] as num).toInt(),
      aperture: d('aperture'),
      minExposureNs: i('minExposureNs'),
      maxExposureNs: i('maxExposureNs'),
      minIso: i('minIso'),
      maxIso: i('maxIso'),
      frameLuma: d('frameLuma'),
      cropLuma: d('cropLuma'),
      spotLuma: d('spotLuma'),
      histogram: List<int>.unmodifiable(
          (req('histogram') as List<Object?>).map((e) => (e as num).toInt())),
    );
  }

  final int exposureNs;
  final int sensitivity;

  /// Percent; 100 = none.
  final int boost;
  final double aperture;
  final int minExposureNs, maxExposureNs, minIso, maxIso;

  /// Mean linear luma, 0..1.
  final double frameLuma, cropLuma, spotLuma;

  /// 64 bins of the crop.
  final List<int> histogram;
}

enum MeterArea { average, spot }

class Reading {
  const Reading(this.ev100, this.flag);

  /// Always finite, even when [flag] is under/over.
  final double ev100;
  final RangeFlag flag;

  @override
  String toString() => 'Reading($ev100, $flag)';
}

Reading readingFrom(MeterStats s,
    {required MeterArea area, double calibration = 0}) {
  final phoneIso = s.sensitivity * s.boost / 100;
  final evAE = _log2(s.aperture * s.aperture / (s.exposureNs / 1e9)) -
      _log2(phoneIso / 100);
  final region = area == MeterArea.spot ? s.spotLuma : s.cropLuma;
  final ev100 = evAE +
      _log2(math.max(region, _lumaFloor) / math.max(s.frameLuma, _lumaFloor)) +
      calibration;

  var flag = RangeFlag.ok;
  if (s.exposureNs >= 0.95 * s.maxExposureNs &&
      s.sensitivity >= 0.95 * s.maxIso &&
      region < 0.01) {
    flag = RangeFlag.under;
  } else if (s.exposureNs <= 1.05 * s.minExposureNs &&
      s.sensitivity <= 1.05 * s.minIso &&
      region > 0.9) {
    flag = RangeFlag.over;
  }
  return Reading(ev100, flag);
}
