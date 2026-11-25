// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:grain/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = GrainDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 does not corrupt data', () async {
    final oldUserProfilesData = <v1.UserProfilesData>[
      const v1.UserProfilesData(
        id: 'canon-a1-mine',
        kind: 'body',
        mount: 'canon-fd',
        json: '{"x":1}',
        updatedAt: 1795255200, // 2026-11-21T10:00Z
      ),
    ];
    final expectedNewUserProfilesData = <v2.UserProfilesData>[
      const v2.UserProfilesData(
        id: 'canon-a1-mine',
        kind: 'body',
        mount: 'canon-fd',
        json: '{"x":1}',
        updatedAt: 1795255200,
      ),
    ];

    final oldFavoritesData = <v1.FavoritesData>[
      const v1.FavoritesData(kind: 'body', profileId: 'canon-a1'),
    ];
    final expectedNewFavoritesData = <v2.FavoritesData>[
      const v2.FavoritesData(kind: 'body', profileId: 'canon-a1'),
    ];

    final oldGearSelectionsData = <v1.GearSelectionsData>[
      const v1.GearSelectionsData(
        id: 0,
        bodyId: 'canon-a1',
        lensId: 'canon-fd-50-1.8',
        focal: 50.0,
      ),
    ];
    final expectedNewGearSelectionsData = <v2.GearSelectionsData>[
      const v2.GearSelectionsData(
        id: 0,
        bodyId: 'canon-a1',
        lensId: 'canon-fd-50-1.8',
        focal: 50.0,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: GrainDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.userProfiles, oldUserProfilesData);
        batch.insertAll(oldDb.favorites, oldFavoritesData);
        batch.insertAll(oldDb.gearSelections, oldGearSelectionsData);
      },
      validateItems: (newDb) async {
        expect(
          await newDb.select(newDb.userProfiles).get(),
          expectedNewUserProfilesData,
        );
        expect(
          await newDb.select(newDb.favorites).get(),
          expectedNewFavoritesData,
        );
        expect(
          await newDb.select(newDb.gearSelections).get(),
          expectedNewGearSelectionsData,
        );
        expect(await newDb.select(newDb.rolls).get(), isEmpty);
        expect(await newDb.select(newDb.frames).get(), isEmpty);
        expect(await newDb.select(newDb.savedReadings).get(), isEmpty);
      },
    );
  });

  test(
    'migration from v2 to v3 keeps rolls and leaves latitude null',
    () async {
      final oldRolls = <v2.RollsData>[
        const v2.RollsData(
          id: 'r1',
          number: 3,
          filmStock: 'Ilford HP5 Plus',
          filmType: 'bw-neg',
          boxIso: 400,
          pushThirds: 3,
          bodyId: 'canon-a1',
          bodyMake: 'Canon',
          bodyModel: 'A-1',
          format: '135',
          size: 36,
          startFrame: '1',
          notes: 'first',
          status: 'active',
          startedAt: 1795255200,
          finishedAt: null,
          updatedAt: 1795255300,
        ),
      ];
      final expectedNewRolls = <v3.RollsData>[
        const v3.RollsData(
          id: 'r1',
          number: 3,
          filmStock: 'Ilford HP5 Plus',
          filmType: 'bw-neg',
          boxIso: 400,
          pushThirds: 3,
          bodyId: 'canon-a1',
          bodyMake: 'Canon',
          bodyModel: 'A-1',
          format: '135',
          size: 36,
          startFrame: '1',
          notes: 'first',
          latitudeUnderHalves: null,
          latitudeOverHalves: null,
          status: 'active',
          startedAt: 1795255200,
          finishedAt: null,
          updatedAt: 1795255300,
        ),
      ];

      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: GrainDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.rolls, oldRolls);
        },
        validateItems: (newDb) async {
          expect(await newDb.select(newDb.rolls).get(), expectedNewRolls);
        },
      );
    },
  );

  test('migration from v3 to v4 gives each frame its roll camera', () async {
    v3.RollsData rollAt(String id, String? bodyId, String make, String model) =>
        v3.RollsData(
          id: id,
          number: id == 'r1' ? 1 : 2,
          filmStock: 'Ilford HP5 Plus',
          filmType: 'bw-neg',
          boxIso: 400,
          pushThirds: 0,
          bodyId: bodyId,
          bodyMake: make,
          bodyModel: model,
          format: '135',
          size: 36,
          startFrame: '1',
          notes: '',
          status: 'finished',
          startedAt: 1795255200,
          updatedAt: 1795255300,
        );
    final oldRolls = [
      rollAt('r1', 'canon-a1', 'Canon', 'A-1'),
      rollAt('r2', null, '', ''),
    ];
    v3.FramesData oldFrame(String id, String rollId, int n) => v3.FramesData(
      id: id,
      rollId: rollId,
      position: n,
      number: n + 1,
      aperture: 5.6,
      shutter: '1/125',
      note: 'n$n',
      updatedAt: 1795255400,
    );
    final oldFrames = [
      oldFrame('f1', 'r1', 0),
      oldFrame('f2', 'r1', 1),
      oldFrame('f3', 'r2', 0),
    ];
    v4.FramesData newFrame(
      String id,
      String rollId,
      int n,
      String? bodyId,
      String make,
      String model,
    ) => v4.FramesData(
      id: id,
      rollId: rollId,
      position: n,
      number: n + 1,
      aperture: 5.6,
      shutter: '1/125',
      note: 'n$n',
      updatedAt: 1795255400,
      bodyId: bodyId,
      bodyMake: make,
      bodyModel: model,
    );
    final expectedFrames = [
      newFrame('f1', 'r1', 0, 'canon-a1', 'Canon', 'A-1'),
      newFrame('f2', 'r1', 1, 'canon-a1', 'Canon', 'A-1'),
      newFrame('f3', 'r2', 0, null, '', ''),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: GrainDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.rolls, oldRolls);
        batch.insertAll(oldDb.frames, oldFrames);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.frames).get(), expectedFrames);
        expect(await newDb.select(newDb.rolls).get(), hasLength(2));
      },
    );
  });
}
