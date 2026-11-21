import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/db/database.dart';
import 'package:grain/exposure/scales.dart';
import 'package:grain/gear/gear_repository.dart';
import 'package:grain/gear/model.dart';

const _a1 = Body(
  id: 'canon-a1',
  make: 'Canon',
  model: 'A-1',
  mount: 'canon-fd',
  format: FilmFormat.f135,
  frames: 36,
  shutter: ['30', '1', '1/2', '1/60', '1/1000', 'B'],
  isoMin: 6,
  isoMax: 12800,
);

const _lens = Lens(
  id: 'canon-fd-50-1.8',
  make: 'Canon',
  name: 'FD 50mm f/1.8',
  mount: 'canon-fd',
  focalMin: 50,
  focalMax: 50,
  maxAperture: [ApertureAt(50, 1.8)],
  minAperture: 16,
  apertureStep: StepSize.full,
);

void main() {
  for (final (name, make) in <(String, GearRepository Function())>[
    ('memory', () => MemoryGearRepository()),
    (
      'drift',
      () => DriftGearRepository(GrainDatabase(NativeDatabase.memory())),
    ),
  ]) {
    group(name, () {
      late GearRepository repo;
      setUp(() => repo = make());

      test('saved profiles come back equal; same id upserts', () async {
        await repo.saveProfile(_a1);
        await repo.saveProfile(_lens);
        expect(await repo.userBodies(), [_a1]);
        expect(await repo.userLenses(), [_lens]);
        final mine = _a1.copyWith(model: 'A-1 mine');
        await repo.saveProfile(mine);
        expect(await repo.userBodies(), [mine]);
      });

      test('favorites toggle per kind', () async {
        await repo.setFavorite(ProfileKind.body, 'canon-a1', true);
        expect(await repo.favorites(ProfileKind.body), {'canon-a1'});
        expect(await repo.favorites(ProfileKind.lens), isEmpty);
        await repo.setFavorite(ProfileKind.body, 'canon-a1', true);
        expect(await repo.favorites(ProfileKind.body), {'canon-a1'});
        await repo.setFavorite(ProfileKind.body, 'canon-a1', false);
        expect(await repo.favorites(ProfileKind.body), isEmpty);
      });

      test('selection defaults to nothing and round-trips', () async {
        expect(await repo.selection(), const StoredSelection());
        const s = StoredSelection(
          bodyId: 'canon-a1',
          lensId: 'canon-fd-50-1.8',
          focal: 50,
        );
        await repo.saveSelection(s);
        expect(await repo.selection(), s);
        await repo.saveSelection(const StoredSelection());
        expect(await repo.selection(), const StoredSelection());
      });

      test('deleting a profile drops its favorite and selection', () async {
        await repo.saveProfile(_a1);
        await repo.setFavorite(ProfileKind.body, 'canon-a1', true);
        await repo.saveSelection(
          const StoredSelection(
            bodyId: 'canon-a1',
            lensId: 'canon-fd-50-1.8',
            focal: 50,
          ),
        );
        await repo.deleteProfile(ProfileKind.body, 'canon-a1');
        expect(await repo.userBodies(), isEmpty);
        expect(await repo.favorites(ProfileKind.body), isEmpty);
        final s = await repo.selection();
        expect(s.bodyId, isNull);
        expect(s.lensId, 'canon-fd-50-1.8');
        expect(s.focal, 50);
      });
    });
  }

  group('drift only', () {
    test('data survives closing and reopening the file', () async {
      final dir = Directory.systemTemp.createTempSync('grain_db');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/grain.sqlite');
      var db = GrainDatabase(NativeDatabase(file));
      await DriftGearRepository(db).saveProfile(_a1);
      await db.close();
      db = GrainDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(await DriftGearRepository(db).userBodies(), [_a1]);
      expect(db.schemaVersion, 1);
    });

    test('a corrupt stored row is skipped', () async {
      final db = GrainDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftGearRepository(db);
      await repo.saveProfile(_a1);
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: 'broken',
              kind: ProfileKind.body,
              mount: 'x',
              json: '{}',
              updatedAt: DateTime(2026),
            ),
          );
      expect(await repo.userBodies(), [_a1]);
    });
  });
}
