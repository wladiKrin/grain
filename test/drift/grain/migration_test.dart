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
}
