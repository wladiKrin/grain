import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/rolls/model.dart';

import 'database.steps.dart';

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

/// Columns shared by logged frames and saved readings.
mixin ExposureColumns on Table {
  TextColumn get mode => textEnum<MeterMode>().nullable()();
  RealColumn get aperture => real().nullable()();
  TextColumn get shutter => text().nullable()();
  RealColumn get exposureTime => real().nullable()();
  IntColumn get iso => integer().nullable()();
  TextColumn get lensId => text().nullable()();
  TextColumn get lensMake => text().nullable()();
  TextColumn get lensName => text().nullable()();
  RealColumn get focal => real().nullable()();
  RealColumn get meteredEv => real().nullable()();
  RealColumn get offsetStops => real().nullable()();
  TextColumn get area => textEnum<MeterArea>().nullable()();
  DateTimeColumn get takenAt => dateTime().nullable()();
  IntColumn get utcOffsetMinutes => integer().nullable()();
  TextColumn get note => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get locationAccuracy => real().nullable()();

  /// Snapshot file name (`<uuid>.jpg`), never a path.
  TextColumn get snapshot => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('RollRow')
class Rolls extends Table {
  TextColumn get id => text()();
  IntColumn get number => integer()();
  TextColumn get filmStock => text()();

  /// FilmType.id
  TextColumn get filmType => text()();
  IntColumn get boxIso => integer()();
  IntColumn get pushThirds => integer()();
  TextColumn get bodyId => text().nullable()();
  TextColumn get bodyMake => text()();
  TextColumn get bodyModel => text()();

  /// FilmFormat.id
  TextColumn get format => text()();
  IntColumn get size => integer()();

  /// StartFrame.label
  TextColumn get startFrame => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get status => textEnum<RollStatus>()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FrameRow')
@TableIndex(name: 'frames_roll_position', columns: {#rollId, #position})
class Frames extends Table with ExposureColumns {
  TextColumn get id => text()();
  TextColumn get rollId =>
      text().references(Rolls, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  IntColumn get number => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SavedReadingRow')
class SavedReadings extends Table with ExposureColumns {
  TextColumn get id => text()();
  TextColumn get bodyId => text().nullable()();
  TextColumn get bodyMake => text()();
  TextColumn get bodyModel => text()();

  /// FilmFormat.id
  TextColumn get format => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// To change the schema: edit the tables, bump [schemaVersion], run
/// `dart run build_runner build` then `dart run drift_dev make-migrations`,
/// and add a `fromNToM` step to the `stepByStep` call in [migration].
@DriftDatabase(
  tables: [
    UserProfiles,
    Favorites,
    GearSelections,
    Rolls,
    Frames,
    SavedReadings,
  ],
)
class GrainDatabase extends _$GrainDatabase {
  GrainDatabase(super.e);

  factory GrainDatabase.open() => GrainDatabase(driftDatabase(name: 'grain'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.rolls);
        await m.createTable(schema.frames);
        await m.createTable(schema.savedReadings);
        await m.createIndex(schema.framesRollPosition);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
