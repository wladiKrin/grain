import 'dart:math' as math;

import 'package:grain/exposure/scales.dart';

enum FilmFormat {
  f135('135', '35 mm', 36, 24, 36),
  half('135-half', 'Half frame', 18, 24, 72),
  f645('120-645', '6×4.5', 56, 41.5, 15),
  f66('120-66', '6×6', 56, 56, 12),
  f67('120-67', '6×7', 70, 56, 10),
  f69('120-69', '6×9', 84, 56, 8);

  const FilmFormat(
    this.id,
    this.label,
    this.widthMm,
    this.heightMm,
    this.defaultFrames,
  );

  final String id;
  final String label;
  final double widthMm;
  final double heightMm;
  final int defaultFrames;

  double get diagonalMm => math.sqrt(widthMm * widthMm + heightMm * heightMm);

  /// Short side over long side.
  double get portraitAspect =>
      widthMm < heightMm ? widthMm / heightMm : heightMm / widthMm;

  /// Width over height of the frame held sideways ([landscape]) or upright.
  double aspect({required bool landscape}) =>
      landscape ? 1 / portraitAspect : portraitAspect;

  static FilmFormat? byId(String id) {
    for (final f in values) {
      if (f.id == id) return f;
    }
    return null;
  }
}

enum ProfileKind { body, lens }

sealed class GearDoc {
  const GearDoc();
}

sealed class GearProfile extends GearDoc {
  const GearProfile();
  String get id;
  String get make;
  String get mount;
  ProfileKind get kind;
  String get displayName;
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final class Body extends GearProfile {
  const Body({
    required this.id,
    required this.make,
    required this.model,
    required this.mount,
    required this.format,
    required this.frames,
    required this.shutter,
    this.isoMin = 6,
    this.isoMax = 12800,
  });

  @override
  final String id;
  @override
  final String make;
  final String model;
  @override
  final String mount;
  final FilmFormat format;
  final int frames;
  final List<String> shutter;
  final int isoMin;
  final int isoMax;

  bool get hasBulb => shutter.contains('B') || shutter.contains('T');

  @override
  ProfileKind get kind => ProfileKind.body;

  @override
  String get displayName => '$make $model';

  Body copyWith({
    String? id,
    String? make,
    String? model,
    String? mount,
    FilmFormat? format,
    int? frames,
    List<String>? shutter,
    int? isoMin,
    int? isoMax,
  }) => Body(
    id: id ?? this.id,
    make: make ?? this.make,
    model: model ?? this.model,
    mount: mount ?? this.mount,
    format: format ?? this.format,
    frames: frames ?? this.frames,
    shutter: shutter ?? this.shutter,
    isoMin: isoMin ?? this.isoMin,
    isoMax: isoMax ?? this.isoMax,
  );

  @override
  bool operator ==(Object other) =>
      other is Body &&
      other.id == id &&
      other.make == make &&
      other.model == model &&
      other.mount == mount &&
      other.format == format &&
      other.frames == frames &&
      _listEq(other.shutter, shutter) &&
      other.isoMin == isoMin &&
      other.isoMax == isoMax;

  @override
  int get hashCode => Object.hash(
    id,
    make,
    model,
    mount,
    format,
    frames,
    Object.hashAll(shutter),
    isoMin,
    isoMax,
  );
}

class ApertureAt {
  const ApertureAt(this.focal, this.aperture);
  final double focal;
  final double aperture;

  @override
  bool operator ==(Object other) =>
      other is ApertureAt && other.focal == focal && other.aperture == aperture;

  @override
  int get hashCode => Object.hash(focal, aperture);

  @override
  String toString() => 'ApertureAt($focal, $aperture)';
}

final class Lens extends GearProfile {
  const Lens({
    required this.id,
    required this.make,
    required this.name,
    required this.mount,
    required this.focalMin,
    required this.focalMax,
    required this.maxAperture,
    required this.minAperture,
    required this.apertureStep,
  });

  @override
  final String id;
  @override
  final String make;
  final String name;
  @override
  final String mount;
  final double focalMin;
  final double focalMax;
  final List<ApertureAt> maxAperture;
  final double minAperture;
  final StepSize apertureStep;

  bool get isZoom => focalMax > focalMin;

  @override
  ProfileKind get kind => ProfileKind.lens;

  @override
  String get displayName => name;

  /// "FD 50mm f/1.8" becomes "FD 50/1.8".
  String get shortName =>
      name.replaceAllMapped(RegExp(r'(\d)mm f/'), (m) => '${m[1]}/');

  Lens copyWith({
    String? id,
    String? make,
    String? name,
    String? mount,
    double? focalMin,
    double? focalMax,
    List<ApertureAt>? maxAperture,
    double? minAperture,
    StepSize? apertureStep,
  }) => Lens(
    id: id ?? this.id,
    make: make ?? this.make,
    name: name ?? this.name,
    mount: mount ?? this.mount,
    focalMin: focalMin ?? this.focalMin,
    focalMax: focalMax ?? this.focalMax,
    maxAperture: maxAperture ?? this.maxAperture,
    minAperture: minAperture ?? this.minAperture,
    apertureStep: apertureStep ?? this.apertureStep,
  );

  @override
  bool operator ==(Object other) =>
      other is Lens &&
      other.id == id &&
      other.make == make &&
      other.name == name &&
      other.mount == mount &&
      other.focalMin == focalMin &&
      other.focalMax == focalMax &&
      _listEq(other.maxAperture, maxAperture) &&
      other.minAperture == minAperture &&
      other.apertureStep == apertureStep;

  @override
  int get hashCode => Object.hash(
    id,
    make,
    name,
    mount,
    focalMin,
    focalMax,
    Object.hashAll(maxAperture),
    minAperture,
    apertureStep,
  );
}

final class Kit extends GearDoc {
  const Kit(this.body, this.lenses);
  final Body body;
  final List<Lens> lenses;
}
