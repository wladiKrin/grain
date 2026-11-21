import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:grain/db/database.dart';
import 'package:grain/gear/codec.dart';
import 'package:grain/gear/model.dart';

class StoredSelection {
  const StoredSelection({this.bodyId, this.lensId, this.focal});
  final String? bodyId;
  final String? lensId;
  final double? focal;

  @override
  bool operator ==(Object other) =>
      other is StoredSelection &&
      other.bodyId == bodyId &&
      other.lensId == lensId &&
      other.focal == focal;

  @override
  int get hashCode => Object.hash(bodyId, lensId, focal);
}

abstract class GearRepository {
  Future<List<Body>> userBodies();
  Future<List<Lens>> userLenses();

  /// Upsert by (kind, id).
  Future<void> saveProfile(GearProfile p);

  /// Also removes its favorite and clears it from the selection.
  Future<void> deleteProfile(ProfileKind kind, String id);
  Future<Set<String>> favorites(ProfileKind kind);
  Future<void> setFavorite(ProfileKind kind, String id, bool on);
  Future<StoredSelection> selection();
  Future<void> saveSelection(StoredSelection s);
}

StoredSelection _withoutProfile(
  StoredSelection s,
  ProfileKind kind,
  String id,
) => switch (kind) {
  ProfileKind.body when s.bodyId == id => StoredSelection(
    lensId: s.lensId,
    focal: s.focal,
  ),
  ProfileKind.lens when s.lensId == id => StoredSelection(
    bodyId: s.bodyId,
    focal: s.focal,
  ),
  _ => s,
};

class DriftGearRepository implements GearRepository {
  DriftGearRepository(this.db);
  final GrainDatabase db;

  Future<List<T>> _load<T extends GearProfile>(ProfileKind kind) async {
    final rows =
        await (db.select(db.userProfiles)
              ..where((t) => t.kind.equalsValue(kind))
              ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)]))
            .get();
    final out = <T>[];
    for (final row in rows) {
      try {
        final doc = parseGear(jsonDecode(row.json));
        if (doc is T) out.add(doc);
      } catch (e) {
        debugPrint('Grain: skipping stored ${kind.name} ${row.id}: $e');
      }
    }
    return out;
  }

  @override
  Future<List<Body>> userBodies() => _load<Body>(ProfileKind.body);

  @override
  Future<List<Lens>> userLenses() => _load<Lens>(ProfileKind.lens);

  @override
  Future<void> saveProfile(GearProfile p) => db
      .into(db.userProfiles)
      .insertOnConflictUpdate(
        UserProfilesCompanion.insert(
          id: p.id,
          kind: p.kind,
          mount: p.mount,
          json: jsonEncode(gearToJson(p)),
          updatedAt: DateTime.now(),
        ),
      );

  @override
  Future<void> deleteProfile(ProfileKind kind, String id) =>
      db.transaction(() async {
        await (db.delete(
          db.userProfiles,
        )..where((t) => t.kind.equalsValue(kind) & t.id.equals(id))).go();
        await (db.delete(db.favorites)
              ..where((t) => t.kind.equalsValue(kind) & t.profileId.equals(id)))
            .go();
        final s = await selection();
        final cleared = _withoutProfile(s, kind, id);
        if (cleared != s) await saveSelection(cleared);
      });

  @override
  Future<Set<String>> favorites(ProfileKind kind) async {
    final rows = await (db.select(
      db.favorites,
    )..where((t) => t.kind.equalsValue(kind))).get();
    return {for (final r in rows) r.profileId};
  }

  @override
  Future<void> setFavorite(ProfileKind kind, String id, bool on) async {
    if (on) {
      await db
          .into(db.favorites)
          .insertOnConflictUpdate(
            FavoritesCompanion.insert(kind: kind, profileId: id),
          );
    } else {
      await (db.delete(
        db.favorites,
      )..where((t) => t.kind.equalsValue(kind) & t.profileId.equals(id))).go();
    }
  }

  @override
  Future<StoredSelection> selection() async {
    final row = await (db.select(
      db.gearSelections,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    if (row == null) return const StoredSelection();
    return StoredSelection(
      bodyId: row.bodyId,
      lensId: row.lensId,
      focal: row.focal,
    );
  }

  @override
  Future<void> saveSelection(StoredSelection s) => db
      .into(db.gearSelections)
      .insertOnConflictUpdate(
        GearSelectionsCompanion(
          id: const Value(0),
          bodyId: Value(s.bodyId),
          lensId: Value(s.lensId),
          focal: Value(s.focal),
        ),
      );
}

class MemoryGearRepository implements GearRepository {
  final Map<(ProfileKind, String), GearProfile> _profiles = {};
  final Map<ProfileKind, Set<String>> _favorites = {
    for (final k in ProfileKind.values) k: <String>{},
  };
  StoredSelection _selection = const StoredSelection();

  List<T> _of<T extends GearProfile>(ProfileKind kind) => [
    for (final e in _profiles.entries)
      if (e.key.$1 == kind) e.value as T,
  ];

  @override
  Future<List<Body>> userBodies() async => _of<Body>(ProfileKind.body);

  @override
  Future<List<Lens>> userLenses() async => _of<Lens>(ProfileKind.lens);

  @override
  Future<void> saveProfile(GearProfile p) async =>
      _profiles[(p.kind, p.id)] = p;

  @override
  Future<void> deleteProfile(ProfileKind kind, String id) async {
    _profiles.remove((kind, id));
    _favorites[kind]!.remove(id);
    _selection = _withoutProfile(_selection, kind, id);
  }

  @override
  Future<Set<String>> favorites(ProfileKind kind) async => {
    ..._favorites[kind]!,
  };

  @override
  Future<void> setFavorite(ProfileKind kind, String id, bool on) async {
    if (on) {
      _favorites[kind]!.add(id);
    } else {
      _favorites[kind]!.remove(id);
    }
  }

  @override
  Future<StoredSelection> selection() async => _selection;

  @override
  Future<void> saveSelection(StoredSelection s) async => _selection = s;
}
