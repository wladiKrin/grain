import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../gear/model.dart';
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

Roll? _rollFromRow(RollRow r) {
  final type = FilmType.byId(r.filmType);
  final format = FilmFormat.byId(r.format);
  final start = StartFrame.byLabel(r.startFrame);
  if (type == null || format == null || start == null) {
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
    status: r.status,
    startedAt: r.startedAt,
    finishedAt: r.finishedAt,
    updatedAt: r.updatedAt,
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
  status: Value(r.status),
  startedAt: Value(r.startedAt),
  finishedAt: Value(r.finishedAt),
  updatedAt: Value(r.updatedAt),
);

Frame _frameFromRow(FrameRow r) => Frame(
  id: r.id,
  rollId: r.rollId,
  position: r.position,
  number: r.number,
  exposure: Exposure(
    mode: r.mode,
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
    area: r.area,
  ),
  takenAt: r.takenAt,
  utcOffsetMinutes: r.utcOffsetMinutes,
  note: r.note,
  location: _geo(r.latitude, r.longitude, r.locationAccuracy),
  snapshot: r.snapshot,
  updatedAt: r.updatedAt,
);

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
    mode: Value(e.mode),
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
    area: Value(e.area),
    takenAt: Value(f.takenAt),
    utcOffsetMinutes: Value(f.utcOffsetMinutes),
    note: Value(f.note),
    latitude: Value(f.location?.latitude),
    longitude: Value(f.location?.longitude),
    locationAccuracy: Value(f.location?.accuracy),
    snapshot: Value(f.snapshot),
    updatedAt: Value(f.updatedAt),
  );
}

SavedReading? _readingFromRow(SavedReadingRow r) {
  final format = FilmFormat.byId(r.format);
  if (format == null || r.takenAt == null) {
    debugPrint('Skipping saved reading ${r.id}: unreadable row');
    return null;
  }
  return SavedReading(
    id: r.id,
    bodyId: r.bodyId,
    bodyMake: r.bodyMake,
    bodyModel: r.bodyModel,
    format: format,
    exposure: Exposure(
      mode: r.mode,
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
      area: r.area,
    ),
    takenAt: r.takenAt!,
    utcOffsetMinutes: r.utcOffsetMinutes ?? 0,
    note: r.note,
    location: _geo(r.latitude, r.longitude, r.locationAccuracy),
    snapshot: r.snapshot,
    updatedAt: r.updatedAt,
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
    mode: Value(e.mode),
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
    area: Value(e.area),
    takenAt: Value(s.takenAt),
    utcOffsetMinutes: Value(s.utcOffsetMinutes),
    note: Value(s.note),
    latitude: Value(s.location?.latitude),
    longitude: Value(s.location?.longitude),
    locationAccuracy: Value(s.location?.accuracy),
    snapshot: Value(s.snapshot),
    updatedAt: Value(s.updatedAt),
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
    return rows.map(_frameFromRow).toList();
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
  Future<void> saveRoll(Roll r) async => _rolls[r.id] = r;

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
      _frames[f.id] = f;
    }
  }

  @override
  Future<void> deleteFrames(List<String> ids) async =>
      ids.forEach(_frames.remove);

  @override
  Future<List<SavedReading>> readings() async =>
      _readings.values.toList()..sort((a, b) => b.takenAt.compareTo(a.takenAt));

  @override
  Future<void> saveReading(SavedReading r) async => _readings[r.id] = r;

  @override
  Future<void> deleteReading(String id) async => _readings.remove(id);

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}
