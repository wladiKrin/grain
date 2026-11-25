import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../exposure/mode.dart';
import '../gear/model.dart';
import '../metering/reading.dart';
import 'model.dart';

abstract class RollRepository {
  Future<List<Roll>> rolls();
  Future<void> saveRoll(Roll r);

  /// Also removes the roll's frames.
  Future<void> deleteRoll(String id);

  /// In position order.
  Future<List<Frame>> frames(String rollId);

  /// Upsert, in one transaction.
  Future<void> saveFrames(List<Frame> frames);
  Future<void> deleteFrames(List<String> ids);

  /// Newest first.
  Future<List<SavedReading>> readings();
  Future<void> saveReading(SavedReading r);
  Future<void> deleteReading(String id);
  Future<T> transaction<T>(Future<T> Function() action);
}

/// Whole seconds, UTC: what the database stores and returns, applied by both
/// repositories so they behave identically.
DateTime _utcSeconds(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
  t.millisecondsSinceEpoch ~/ 1000 * 1000,
  isUtc: true,
);

DateTime? _utcSecondsOrNull(DateTime? t) => t == null ? null : _utcSeconds(t);

Roll _normRoll(Roll r) => r.copyWith(
  startedAt: _utcSeconds(r.startedAt),
  finishedAt: () => _utcSecondsOrNull(r.finishedAt),
  updatedAt: _utcSeconds(r.updatedAt),
);

Frame _normFrame(Frame f) => f.copyWith(
  takenAt: () => _utcSecondsOrNull(f.takenAt),
  updatedAt: _utcSeconds(f.updatedAt),
);

SavedReading _normReading(SavedReading s) => s.copyWith(
  takenAt: _utcSeconds(s.takenAt),
  updatedAt: _utcSeconds(s.updatedAt),
);

T? _byName<T extends Enum>(List<T> values, String? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Reads the exposure columns; null when a stored enum name is unknown.
Exposure? _exposureOf({
  required String id,
  required String? mode,
  required String? area,
  required double? aperture,
  required String? shutter,
  required double? exposureTime,
  required int? iso,
  required String? lensId,
  required String? lensMake,
  required String? lensName,
  required double? focal,
  required double? meteredEv,
  required double? offset,
}) {
  final m = mode == null ? null : _byName(MeterMode.values, mode);
  final a = area == null ? null : _byName(MeterArea.values, area);
  if ((mode != null && m == null) || (area != null && a == null)) {
    debugPrint('Skipping row $id: unknown mode/area');
    return null;
  }
  return Exposure(
    mode: m,
    aperture: aperture,
    shutter: shutter,
    exposureTime: exposureTime,
    iso: iso,
    lensId: lensId,
    lensMake: lensMake,
    lensName: lensName,
    focal: focal,
    meteredEv: meteredEv,
    offset: offset,
    area: a,
  );
}

Roll? _rollFromRow(RollRow r) {
  final type = FilmType.byId(r.filmType);
  final format = FilmFormat.byId(r.format);
  final start = StartFrame.byLabel(r.startFrame);
  final status = _byName(RollStatus.values, r.status);
  if (type == null || format == null || start == null || status == null) {
    debugPrint('Skipping roll ${r.id}: unknown enum id in row');
    return null;
  }
  return Roll(
    id: r.id,
    number: r.number,
    filmStock: r.filmStock,
    filmType: type,
    boxIso: r.boxIso,
    pushThirds: r.pushThirds,
    bodyId: r.bodyId,
    bodyMake: r.bodyMake,
    bodyModel: r.bodyModel,
    format: format,
    size: r.size,
    startFrame: start,
    notes: r.notes,
    latitudeUnderHalves: r.latitudeUnderHalves,
    latitudeOverHalves: r.latitudeOverHalves,
    status: status,
    startedAt: _utcSeconds(r.startedAt),
    finishedAt: _utcSecondsOrNull(r.finishedAt),
    updatedAt: _utcSeconds(r.updatedAt),
  );
}

RollsCompanion _rollToCompanion(Roll r) => RollsCompanion(
  id: Value(r.id),
  number: Value(r.number),
  filmStock: Value(r.filmStock),
  filmType: Value(r.filmType.id),
  boxIso: Value(r.boxIso),
  pushThirds: Value(r.pushThirds),
  bodyId: Value(r.bodyId),
  bodyMake: Value(r.bodyMake),
  bodyModel: Value(r.bodyModel),
  format: Value(r.format.id),
  size: Value(r.size),
  startFrame: Value(r.startFrame.label),
  notes: Value(r.notes),
  latitudeUnderHalves: Value(r.latitudeUnderHalves),
  latitudeOverHalves: Value(r.latitudeOverHalves),
  status: Value(r.status.name),
  startedAt: Value(_utcSeconds(r.startedAt)),
  finishedAt: Value(_utcSecondsOrNull(r.finishedAt)),
  updatedAt: Value(_utcSeconds(r.updatedAt)),
);

Frame? _frameFromRow(FrameRow r) {
  final e = _exposureOf(
    id: r.id,
    mode: r.mode,
    area: r.area,
    aperture: r.aperture,
    shutter: r.shutter,
    exposureTime: r.exposureTime,
    iso: r.iso,
    lensId: r.lensId,
    lensMake: r.lensMake,
    lensName: r.lensName,
    focal: r.focal,
    meteredEv: r.meteredEv,
    offset: r.offsetStops,
  );
  if (e == null) return null;
  return Frame(
    id: r.id,
    rollId: r.rollId,
    position: r.position,
    number: r.number,
    bodyId: r.bodyId,
    bodyMake: r.bodyMake,
    bodyModel: r.bodyModel,
    exposure: e,
    takenAt: _utcSecondsOrNull(r.takenAt),
    utcOffsetMinutes: r.utcOffsetMinutes,
    note: r.note,
    location: _geo(r.latitude, r.longitude, r.locationAccuracy),
    snapshot: r.snapshot,
    updatedAt: _utcSeconds(r.updatedAt),
  );
}

GeoFix? _geo(double? lat, double? lon, double? acc) =>
    lat == null || lon == null
    ? null
    : GeoFix(latitude: lat, longitude: lon, accuracy: acc);

FramesCompanion _frameToCompanion(Frame f) {
  final e = f.exposure;
  return FramesCompanion(
    id: Value(f.id),
    rollId: Value(f.rollId),
    position: Value(f.position),
    number: Value(f.number),
    bodyId: Value(f.bodyId),
    bodyMake: Value(f.bodyMake),
    bodyModel: Value(f.bodyModel),
    mode: Value(e.mode?.name),
    aperture: Value(e.aperture),
    shutter: Value(e.shutter),
    exposureTime: Value(e.exposureTime),
    iso: Value(e.iso),
    lensId: Value(e.lensId),
    lensMake: Value(e.lensMake),
    lensName: Value(e.lensName),
    focal: Value(e.focal),
    meteredEv: Value(e.meteredEv),
    offsetStops: Value(e.offset),
    area: Value(e.area?.name),
    takenAt: Value(_utcSecondsOrNull(f.takenAt)),
    utcOffsetMinutes: Value(f.utcOffsetMinutes),
    note: Value(f.note),
    latitude: Value(f.location?.latitude),
    longitude: Value(f.location?.longitude),
    locationAccuracy: Value(f.location?.accuracy),
    snapshot: Value(f.snapshot),
    updatedAt: Value(_utcSeconds(f.updatedAt)),
  );
}

SavedReading? _readingFromRow(SavedReadingRow r) {
  final format = FilmFormat.byId(r.format);
  final e = _exposureOf(
    id: r.id,
    mode: r.mode,
    area: r.area,
    aperture: r.aperture,
    shutter: r.shutter,
    exposureTime: r.exposureTime,
    iso: r.iso,
    lensId: r.lensId,
    lensMake: r.lensMake,
    lensName: r.lensName,
    focal: r.focal,
    meteredEv: r.meteredEv,
    offset: r.offsetStops,
  );
  // takenAt and utcOffsetMinutes are required by the model but nullable in the
  // shared column set; a row missing either is unreadable, not defaulted.
  if (format == null ||
      e == null ||
      r.takenAt == null ||
      r.utcOffsetMinutes == null) {
    debugPrint('Skipping saved reading ${r.id}: unreadable row');
    return null;
  }
  return SavedReading(
    id: r.id,
    bodyId: r.bodyId,
    bodyMake: r.bodyMake,
    bodyModel: r.bodyModel,
    format: format,
    exposure: e,
    takenAt: _utcSeconds(r.takenAt!),
    utcOffsetMinutes: r.utcOffsetMinutes!,
    note: r.note,
    location: _geo(r.latitude, r.longitude, r.locationAccuracy),
    snapshot: r.snapshot,
    updatedAt: _utcSeconds(r.updatedAt),
  );
}

SavedReadingsCompanion _readingToCompanion(SavedReading s) {
  final e = s.exposure;
  return SavedReadingsCompanion(
    id: Value(s.id),
    bodyId: Value(s.bodyId),
    bodyMake: Value(s.bodyMake),
    bodyModel: Value(s.bodyModel),
    format: Value(s.format.id),
    mode: Value(e.mode?.name),
    aperture: Value(e.aperture),
    shutter: Value(e.shutter),
    exposureTime: Value(e.exposureTime),
    iso: Value(e.iso),
    lensId: Value(e.lensId),
    lensMake: Value(e.lensMake),
    lensName: Value(e.lensName),
    focal: Value(e.focal),
    meteredEv: Value(e.meteredEv),
    offsetStops: Value(e.offset),
    area: Value(e.area?.name),
    takenAt: Value(_utcSeconds(s.takenAt)),
    utcOffsetMinutes: Value(s.utcOffsetMinutes),
    note: Value(s.note),
    latitude: Value(s.location?.latitude),
    longitude: Value(s.location?.longitude),
    locationAccuracy: Value(s.location?.accuracy),
    snapshot: Value(s.snapshot),
    updatedAt: Value(_utcSeconds(s.updatedAt)),
  );
}

class DriftRollRepository implements RollRepository {
  DriftRollRepository(this.db);
  final GrainDatabase db;

  @override
  Future<List<Roll>> rolls() async {
    final rows = await (db.select(
      db.rolls,
    )..orderBy([(t) => OrderingTerm.asc(t.number)])).get();
    return [for (final r in rows) ?_rollFromRow(r)];
  }

  @override
  Future<void> saveRoll(Roll r) =>
      db.into(db.rolls).insertOnConflictUpdate(_rollToCompanion(r));

  @override
  Future<void> deleteRoll(String id) => db.transaction(() async {
    // Explicit, so it does not depend on the foreign_keys pragma.
    await (db.delete(db.frames)..where((t) => t.rollId.equals(id))).go();
    await (db.delete(db.rolls)..where((t) => t.id.equals(id))).go();
  });

  @override
  Future<List<Frame>> frames(String rollId) async {
    final rows =
        await (db.select(db.frames)
              ..where((t) => t.rollId.equals(rollId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    return [for (final r in rows) ?_frameFromRow(r)];
  }

  @override
  Future<void> saveFrames(List<Frame> frames) => db.transaction(() async {
    for (final f in frames) {
      await db.into(db.frames).insertOnConflictUpdate(_frameToCompanion(f));
    }
  });

  @override
  Future<void> deleteFrames(List<String> ids) =>
      (db.delete(db.frames)..where((t) => t.id.isIn(ids))).go();

  @override
  Future<List<SavedReading>> readings() async {
    final rows = await (db.select(
      db.savedReadings,
    )..orderBy([(t) => OrderingTerm.desc(t.takenAt)])).get();
    return [for (final r in rows) ?_readingFromRow(r)];
  }

  @override
  Future<void> saveReading(SavedReading r) =>
      db.into(db.savedReadings).insertOnConflictUpdate(_readingToCompanion(r));

  @override
  Future<void> deleteReading(String id) =>
      (db.delete(db.savedReadings)..where((t) => t.id.equals(id))).go();

  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      db.transaction(action);
}

class MemoryRollRepository implements RollRepository {
  final Map<String, Roll> _rolls = {};
  final Map<String, Frame> _frames = {};
  final Map<String, SavedReading> _readings = {};

  @override
  Future<List<Roll>> rolls() async =>
      _rolls.values.toList()..sort((a, b) => a.number.compareTo(b.number));

  @override
  Future<void> saveRoll(Roll r) async => _rolls[r.id] = _normRoll(r);

  @override
  Future<void> deleteRoll(String id) async {
    _rolls.remove(id);
    _frames.removeWhere((_, f) => f.rollId == id);
  }

  @override
  Future<List<Frame>> frames(String rollId) async =>
      _frames.values.where((f) => f.rollId == rollId).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  @override
  Future<void> saveFrames(List<Frame> frames) async {
    for (final f in frames) {
      _frames[f.id] = _normFrame(f);
    }
  }

  @override
  Future<void> deleteFrames(List<String> ids) async =>
      ids.forEach(_frames.remove);

  @override
  Future<List<SavedReading>> readings() async =>
      _readings.values.toList()..sort((a, b) => b.takenAt.compareTo(a.takenAt));

  @override
  Future<void> saveReading(SavedReading r) async =>
      _readings[r.id] = _normReading(r);

  @override
  Future<void> deleteReading(String id) async => _readings.remove(id);

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}
