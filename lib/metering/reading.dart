import 'dart:math' as math;

import '../exposure/solver.dart';

double _log2(double x) => math.log(x) / math.ln2;

const double _lumaFloor = 1e-4;

/// Mid grey, linear: the manual engine exposes the metered region near it.
const double midGrey = 0.18;

/// A region this bright or dark (linear) is clipped: its luma no longer
/// measures. Same as the native loop.
const double clipHigh = 0.95, clipLow = 0.002;

/// Share of the region's pixels at the top code that counts as clipped.
const double clipShare = 0.02;

/// With clipped highlights the native loop steps the region down to this
/// luma (its CLIP_FLOOR), and takes no step smaller than [minStepEv]: a
/// region with more than [clipShare] clipped and at least
/// [clipFloor]·2^[minStepEv] is one the loop still re-exposes.
const double clipFloor = 0.1, minStepEv = 0.1;

/// Which exposure a frame's stats come from.
enum MeterEngine {
  /// Grain set exposure time and ISO itself, AE off.
  manual,

  /// The phone's own auto-exposure.
  ae,
}

/// One camera frame's exposure metadata and linear-luma statistics.
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
    this.apertureAssumed = false,
    this.zoom = 1,
    this.camera,
    this.aeState,
    this.engine = MeterEngine.ae,
    this.tonemap,
    this.toneGamma,
    this.requestedExposureNs,
    this.requestedSensitivity,
    this.loop,
    this.atMinExposure = false,
    this.atMaxExposure = false,
    this.cropClip = 0,
    this.spotClip = 0,
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
        (req('histogram') as List<Object?>).map((e) => (e as num).toInt()),
      ),
      apertureAssumed: m['apertureAssumed'] == true,
      zoom: (m['zoom'] as num?)?.toDouble() ?? 1,
      camera: m['camera'] as String?,
      aeState: m['aeState'] as String?,
      engine: m['engine'] == 'manual' ? MeterEngine.manual : MeterEngine.ae,
      tonemap: m['tonemap'] as String?,
      toneGamma: (m['toneGamma'] as num?)?.toDouble(),
      requestedExposureNs: (m['requestedExposureNs'] as num?)?.toInt(),
      requestedSensitivity: (m['requestedSensitivity'] as num?)?.toInt(),
      loop: m['loop'] as String?,
      atMinExposure: m['atMinExposure'] == true,
      atMaxExposure: m['atMaxExposure'] == true,
      cropClip: (m['cropClip'] as num?)?.toDouble() ?? 0,
      spotClip: (m['spotClip'] as num?)?.toDouble() ?? 0,
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

  /// The phone gave no aperture; [aperture] is the f/1.8 fallback.
  final bool apertureAssumed;

  /// The frame's CONTROL_ZOOM_RATIO, active camera ("main", "wide", "tele")
  /// and CONTROL_AE_STATE; for the stats log only.
  final double zoom;
  final String? camera, aeState;

  /// Absent means [MeterEngine.ae].
  final MeterEngine engine;

  /// Manual engine: the tone curve the lumas were linearised with ("srgb",
  /// "gamma2.2"), and its gamma (null: sRGB).
  final String? tonemap;
  final double? toneGamma;

  /// Manual engine: the exposure last asked for; [exposureNs] and
  /// [sensitivity] are what the frame really had, and the EV uses those.
  final int? requestedExposureNs, requestedSensitivity;

  /// Manual engine: the loop's state at this frame ("settling", "steady",
  /// "clipped").
  final String? loop;

  /// Manual engine: the frame ran at the loop's shortest (longest) exposure.
  final bool atMinExposure, atMaxExposure;

  /// Shares of crop and spot pixels at the top code, 0..1.
  final double cropClip, spotClip;
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

/// Null for a frame whose metadata or lumas cannot give a finite EV
/// (non-positive aperture, exposure or ISO; non-finite values), or a manual
/// frame whose region is clipped while the loop can still re-expose: more
/// than [clipShare] of it at the top code counts too. A [held] frame is
/// never re-exposed, so it gives the clipped region's bound flagged over or
/// under instead.
///
/// AE: EV100 = log2(N²/t) − log2(ISO·boost/100/100) + log2(region / frame).
/// Manual: the same exposure term + log2(region / [midGrey]); the frame's own
/// result values, not the requested ones.
Reading? readingFrom(
  MeterStats s, {
  required MeterArea area,
  double calibration = 0,
  bool held = false,
}) {
  if (!(s.aperture.isFinite && s.aperture > 0) ||
      s.exposureNs <= 0 ||
      s.sensitivity <= 0 ||
      s.boost <= 0 ||
      !s.frameLuma.isFinite ||
      !s.cropLuma.isFinite ||
      !s.spotLuma.isFinite ||
      !calibration.isFinite) {
    return null;
  }
  final phoneIso = s.sensitivity * s.boost / 100;
  final evExposure =
      _log2(s.aperture * s.aperture / (s.exposureNs / 1e9)) -
      _log2(phoneIso / 100);
  final region = area == MeterArea.spot ? s.spotLuma : s.cropLuma;
  if (s.engine == MeterEngine.manual) {
    return _manualReading(
      s,
      area,
      region,
      evExposure + calibration,
      held: held,
    );
  }
  final ev100 =
      evExposure +
      _log2(math.max(region, _lumaFloor) / math.max(s.frameLuma, _lumaFloor)) +
      calibration;

  if (!ev100.isFinite) return null;

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

/// Over when the region is clipped bright at the loop's shortest exposure,
/// under when it is black at its longest; a clipped region the loop can
/// still re-expose gives no reading (the next frames will), or, from a
/// [held] frame that no frame will replace, the bound with its flag.
Reading? _manualReading(
  MeterStats s,
  MeterArea area,
  double region,
  double evAtMidGrey, {
  required bool held,
}) {
  final ev100 = evAtMidGrey + _log2(math.max(region, _lumaFloor) / midGrey);
  if (!ev100.isFinite) return null;
  final clip = area == MeterArea.spot ? s.spotClip : s.cropClip;
  final bright = region >= clipHigh || clip > clipShare;
  if (s.atMinExposure && bright) return Reading(ev100, RangeFlag.over);
  if (s.atMaxExposure && region <= clipLow) {
    return Reading(ev100, RangeFlag.under);
  }
  // Clipped pixels pull the mean down: such a frame under-reads, and the
  // loop is about to step down anyway.
  final relooks =
      clip > clipShare && region >= clipFloor * math.pow(2, minStepEv);
  if (region >= clipHigh || region <= clipLow || relooks) {
    if (!held) return null;
    return Reading(ev100, bright ? RangeFlag.over : RangeFlag.under);
  }
  return Reading(ev100, RangeFlag.ok);
}
