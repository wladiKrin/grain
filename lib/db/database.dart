import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:grain/gear/model.dart';

part 'database.g.dart';

class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<ProfileKind>()();
  TextColumn get mount => text()();

  /// jsonEncode(gearToJson(profile))
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {kind, id};
}

class Favorites extends Table {
  TextColumn get kind => textEnum<ProfileKind>()();
  TextColumn get profileId => text()();

  @override
  Set<Column> get primaryKey => {kind, profileId};
}

/// Single row, id 0.
class GearSelections extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get bodyId => text().nullable()();
  TextColumn get lensId => text().nullable()();
  RealColumn get focal => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Plan 3 adds rolls/frames: bump schemaVersion, run make-migrations, add a
/// stepByStep step.
@DriftDatabase(tables: [UserProfiles, Favorites, GearSelections])
class GrainDatabase extends _$GrainDatabase {
  GrainDatabase(super.e);

  factory GrainDatabase.open() => GrainDatabase(driftDatabase(name: 'grain'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      throw StateError('No migration from schema $from to $to');
    },
  );
}
