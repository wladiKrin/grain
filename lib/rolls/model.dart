import '../exposure/mode.dart';
import '../gear/model.dart';
import '../metering/reading.dart';
import 'numbering.dart';
import 'push.dart';

enum FilmType {
  colorNeg('color-neg', 'Colour negative'),
  bwNeg('bw-neg', 'B&W negative'),
  slide('slide', 'Slide');

  const FilmType(this.id, this.label);
  final String id;
  final String label;

  static FilmType? byId(String id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

enum StartFrame {
  doubleZero('00', -1),
  zero('0', 0),
  one('1', 1);

  const StartFrame(this.label, this.number);
  final String label;
  final int number;

  static StartFrame? byLabel(String s) {
    for (final t in values) {
      if (t.label == s) return t;
    }
    return null;
  }
}

enum RollStatus { active, finished }

class GeoFix {
  const GeoFix({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;

  @override
  bool operator ==(Object other) =>
      other is GeoFix &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracy == accuracy;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracy);
}

class Exposure {
  const Exposure({
    this.mode,
    this.aperture,
    this.shutter,
    this.exposureTime,
    this.iso,
    this.lensId,
    this.lensMake,
    this.lensName,
    this.focal,
    this.meteredEv,
    this.offset,
    this.area,
  });

  static const blank = Exposure();

  final MeterMode? mode;

  /// Nominal f-number.
  final double? aperture;

  /// Dial label: `1/125`, `2"`, `B`.
  final String? shutter;

  /// Nominal seconds.
  final double? exposureTime;
  final int? iso;
  final String? lensId;
  final String? lensMake;
  final String? lensName;
  final double? focal;

  /// EV100 including calibration.
  final double? meteredEv;
  final double? offset;
  final MeterArea? area;

  List<Object?> get _fields => [
    mode,
    aperture,
    shutter,
    exposureTime,
    iso,
    lensId,
    lensMake,
    lensName,
    focal,
    meteredEv,
    offset,
    area,
  ];

  bool get isBlank => _fields.every((f) => f == null);

  Exposure copyWith({
    MeterMode? Function()? mode,
    double? Function()? aperture,
    String? Function()? shutter,
    double? Function()? exposureTime,
    int? Function()? iso,
    String? Function()? lensId,
    String? Function()? lensMake,
    String? Function()? lensName,
    double? Function()? focal,
    double? Function()? meteredEv,
    double? Function()? offset,
    MeterArea? Function()? area,
  }) => Exposure(
    mode: mode != null ? mode() : this.mode,
    aperture: aperture != null ? aperture() : this.aperture,
    shutter: shutter != null ? shutter() : this.shutter,
    exposureTime: exposureTime != null ? exposureTime() : this.exposureTime,
    iso: iso != null ? iso() : this.iso,
    lensId: lensId != null ? lensId() : this.lensId,
    lensMake: lensMake != null ? lensMake() : this.lensMake,
    lensName: lensName != null ? lensName() : this.lensName,
    focal: focal != null ? focal() : this.focal,
    meteredEv: meteredEv != null ? meteredEv() : this.meteredEv,
    offset: offset != null ? offset() : this.offset,
    area: area != null ? area() : this.area,
  );

  @override
  bool operator ==(Object other) {
    if (other is! Exposure) return false;
    final a = _fields, b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);
}

String _bodyName(String? bodyId, String make, String model) =>
    bodyId == null ? 'No camera' : '$make $model';

class Roll {
  const Roll({
    required this.id,
    required this.number,
    required this.filmStock,
    required this.filmType,
    required this.boxIso,
    required this.pushThirds,
    this.bodyId,
    this.bodyMake = '',
    this.bodyModel = '',
    required this.format,
    required this.size,
    required this.startFrame,
    this.notes = '',
    required this.status,
    required this.startedAt,
    this.finishedAt,
    required this.updatedAt,
  });

  final String id;
  final int number;
  final String filmStock;
  final FilmType filmType;
  final int boxIso;
  final int pushThirds;
  final String? bodyId;
  final String bodyMake;
  final String bodyModel;
  final FilmFormat format;
  final int size;
  final StartFrame startFrame;
  final String notes;
  final RollStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final DateTime updatedAt;

  String get bodyName => _bodyName(bodyId, bodyMake, bodyModel);
  int get exposedIso => exposedIsoFor(boxIso, pushThirds) ?? boxIso;
  double get pushStops => pushThirds / 3;
  bool get isActive => status == RollStatus.active;

  List<Object?> get _fields => [
    id,
    number,
    filmStock,
    filmType,
    boxIso,
    pushThirds,
    bodyId,
    bodyMake,
    bodyModel,
    format,
    size,
    startFrame,
    notes,
    status,
    startedAt,
    finishedAt,
    updatedAt,
  ];

  Roll copyWith({
    String? id,
    int? number,
    String? filmStock,
    FilmType? filmType,
    int? boxIso,
    int? pushThirds,
    String? Function()? bodyId,
    String? bodyMake,
    String? bodyModel,
    FilmFormat? format,
    int? size,
    StartFrame? startFrame,
    String? notes,
    RollStatus? status,
    DateTime? startedAt,
    DateTime? Function()? finishedAt,
    DateTime? updatedAt,
  }) => Roll(
    id: id ?? this.id,
    number: number ?? this.number,
    filmStock: filmStock ?? this.filmStock,
    filmType: filmType ?? this.filmType,
    boxIso: boxIso ?? this.boxIso,
    pushThirds: pushThirds ?? this.pushThirds,
    bodyId: bodyId != null ? bodyId() : this.bodyId,
    bodyMake: bodyMake ?? this.bodyMake,
    bodyModel: bodyModel ?? this.bodyModel,
    format: format ?? this.format,
    size: size ?? this.size,
    startFrame: startFrame ?? this.startFrame,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt != null ? finishedAt() : this.finishedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) {
    if (other is! Roll) return false;
    final a = _fields, b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);
}

class Frame {
  const Frame({
    required this.id,
    required this.rollId,
    required this.position,
    required this.number,
    this.exposure = Exposure.blank,
    this.takenAt,
    this.utcOffsetMinutes,
    this.note,
    this.location,
    this.snapshot,
    required this.updatedAt,
  });

  final String id;
  final String rollId;
  final int position;
  final int number;
  final Exposure exposure;
  final DateTime? takenAt;
  final int? utcOffsetMinutes;
  final String? note;
  final GeoFix? location;

  /// File name (`<uuid>.jpg`), never a path.
  final String? snapshot;
  final DateTime updatedAt;

  String get label => frameLabel(number);

  List<Object?> get _fields => [
    id,
    rollId,
    position,
    number,
    exposure,
    takenAt,
    utcOffsetMinutes,
    note,
    location,
    snapshot,
    updatedAt,
  ];

  Frame copyWith({
    String? id,
    String? rollId,
    int? position,
    int? number,
    Exposure? exposure,
    DateTime? Function()? takenAt,
    int? Function()? utcOffsetMinutes,
    String? Function()? note,
    GeoFix? Function()? location,
    String? Function()? snapshot,
    DateTime? updatedAt,
  }) => Frame(
    id: id ?? this.id,
    rollId: rollId ?? this.rollId,
    position: position ?? this.position,
    number: number ?? this.number,
    exposure: exposure ?? this.exposure,
    takenAt: takenAt != null ? takenAt() : this.takenAt,
    utcOffsetMinutes: utcOffsetMinutes != null
        ? utcOffsetMinutes()
        : this.utcOffsetMinutes,
    note: note != null ? note() : this.note,
    location: location != null ? location() : this.location,
    snapshot: snapshot != null ? snapshot() : this.snapshot,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) {
    if (other is! Frame) return false;
    final a = _fields, b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);
}

class SavedReading {
  const SavedReading({
    required this.id,
    this.bodyId,
    this.bodyMake = '',
    this.bodyModel = '',
    required this.format,
    required this.exposure,
    required this.takenAt,
    required this.utcOffsetMinutes,
    this.note,
    this.location,
    this.snapshot,
    required this.updatedAt,
  });

  final String id;
  final String? bodyId;
  final String bodyMake;
  final String bodyModel;
  final FilmFormat format;
  final Exposure exposure;
  final DateTime takenAt;
  final int utcOffsetMinutes;
  final String? note;
  final GeoFix? location;
  final String? snapshot;
  final DateTime updatedAt;

  String get bodyName => _bodyName(bodyId, bodyMake, bodyModel);

  List<Object?> get _fields => [
    id,
    bodyId,
    bodyMake,
    bodyModel,
    format,
    exposure,
    takenAt,
    utcOffsetMinutes,
    note,
    location,
    snapshot,
    updatedAt,
  ];

  SavedReading copyWith({
    String? id,
    String? Function()? bodyId,
    String? bodyMake,
    String? bodyModel,
    FilmFormat? format,
    Exposure? exposure,
    DateTime? takenAt,
    int? utcOffsetMinutes,
    String? Function()? note,
    GeoFix? Function()? location,
    String? Function()? snapshot,
    DateTime? updatedAt,
  }) => SavedReading(
    id: id ?? this.id,
    bodyId: bodyId != null ? bodyId() : this.bodyId,
    bodyMake: bodyMake ?? this.bodyMake,
    bodyModel: bodyModel ?? this.bodyModel,
    format: format ?? this.format,
    exposure: exposure ?? this.exposure,
    takenAt: takenAt ?? this.takenAt,
    utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
    note: note != null ? note() : this.note,
    location: location != null ? location() : this.location,
    snapshot: snapshot != null ? snapshot() : this.snapshot,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) {
    if (other is! SavedReading) return false;
    final a = _fields, b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);
}
