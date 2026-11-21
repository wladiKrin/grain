import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/db/database.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_repository.dart';

final _t0 = DateTime.utc(2026, 11, 21, 10);

Roll _roll(String id, {int number = 1, String? bodyId}) => Roll(
  id: id,
  number: number,
  filmStock: 'Kodak Portra 400',
  filmType: FilmType.colorNeg,
  boxIso: 400,
  pushThirds: -2,
  bodyId: bodyId,
  bodyMake: bodyId == null ? '' : 'Canon',
  bodyModel: bodyId == null ? '' : 'A-1',
  format: FilmFormat.f135,
  size: 36,
  startFrame: StartFrame.doubleZero,
  notes: 'pushed light',
  status: RollStatus.active,
  startedAt: _t0,
  updatedAt: _t0,
);

Frame _frame(String id, String rollId, int position) => Frame(
  id: id,
  rollId: rollId,
  position: position,
  number: position + 1,
  updatedAt: _t0,
);

const _full = Exposure(
  mode: MeterMode.manual,
  aperture: 5.6,
  shutter: '1/125',
  exposureTime: 0.008,
  iso: 200,
  lensId: 'canon-fd-50-1.8',
  lensMake: 'Canon',
  lensName: 'FD 50mm f/1.8',
  focal: 50,
  meteredEv: 12.33,
  offset: -0.67,
  area: MeterArea.spot,
);

void main() {
  for (final (name, make) in <(String, RollRepository Function())>[
    ('memory', () => MemoryRollRepository()),
    (
      'drift',
      () => DriftRollRepository(GrainDatabase(NativeDatabase.memory())),
    ),
  ]) {
    group(name, () {
      late RollRepository repo;
      setUp(() => repo = make());

      test('roll round-trips every field', () async {
        final a = _roll('a', bodyId: 'canon-a1');
        final b = _roll('b', number: 2).copyWith(
          finishedAt: () => null,
          format: FilmFormat.f66,
          size: 12,
          filmType: FilmType.slide,
          startFrame: StartFrame.one,
        );
        final c = _roll('c', number: 3).copyWith(
          status: RollStatus.finished,
          finishedAt: () => DateTime.utc(2026, 12, 1),
        );
        await repo.saveRoll(a);
        await repo.saveRoll(b);
        await repo.saveRoll(c);
        final got = {for (final r in await repo.rolls()) r.id: r};
        expect(got['a'], a);
        expect(got['b'], b);
        expect(got['b']!.bodyId, isNull);
        expect(got['b']!.finishedAt, isNull);
        expect(got['a']!.pushThirds, -2);
        expect(got['a']!.startFrame, StartFrame.doubleZero);
        expect(got['c'], c);
        // saving again updates in place
        await repo.saveRoll(a.copyWith(notes: 'x'));
        expect((await repo.rolls()).length, 3);
      });

      test('latitude overrides persist', () async {
        await repo.saveRoll(_roll('a').copyWith(latitudeUnderHalves: () => -2));
        final r = (await repo.rolls()).single;
        expect(r.latitudeUnderHalves, -2);
        expect(r.latitudeOverHalves, isNull);
      });

      test(
        'frames come back in position order with every exposure field',
        () async {
          await repo.saveRoll(_roll('r'));
          final f2 = _frame('f2', 'r', 2);
          final f0 = _frame('f0', 'r', 0).copyWith(
            exposure: _full,
            takenAt: () => _t0,
            utcOffsetMinutes: () => 120,
            note: () => 'hello',
            location: () =>
                const GeoFix(latitude: 48.2, longitude: 16.37, accuracy: 4.5),
            snapshot: () => 'abc.jpg',
          );
          final f1 = _frame(
            'f1',
            'r',
            1,
          ).copyWith(location: () => const GeoFix(latitude: 1, longitude: 2));
          await repo.saveFrames([f2, f0, f1]);
          final got = await repo.frames('r');
          expect(got.map((f) => f.id), ['f0', 'f1', 'f2']);
          expect(got[0], f0);
          expect(got[0].exposure.offset, -0.67);
          expect(got[0].exposure.area, MeterArea.spot);
          expect(got[0].exposure.mode, MeterMode.manual);
          expect(got[1], f1);
          expect(got[1].location!.accuracy, isNull);
          expect(got[2], f2);
        },
      );

      test('blank frame round-trips as Exposure.blank', () async {
        await repo.saveRoll(_roll('r'));
        await repo.saveFrames([_frame('f', 'r', 0)]);
        final got = (await repo.frames('r')).single;
        expect(got.exposure, Exposure.blank);
        expect(got.exposure.isBlank, isTrue);
        expect(got.location, isNull);
        expect(got.takenAt, isNull);
      });

      test('deleteRoll removes its frames', () async {
        await repo.saveRoll(_roll('r'));
        await repo.saveRoll(_roll('s', number: 2));
        await repo.saveFrames([_frame('f', 'r', 0), _frame('g', 's', 0)]);
        await repo.deleteRoll('r');
        expect((await repo.rolls()).map((r) => r.id), ['s']);
        expect(await repo.frames('r'), isEmpty);
        expect((await repo.frames('s')).map((f) => f.id), ['g']);
      });

      test('deleteFrames removes only the named frames', () async {
        await repo.saveRoll(_roll('r'));
        await repo.saveFrames([_frame('a', 'r', 0), _frame('b', 'r', 1)]);
        await repo.deleteFrames(['a']);
        expect((await repo.frames('r')).map((f) => f.id), ['b']);
      });

      test('saveFrames upserts several frames at once', () async {
        await repo.saveRoll(_roll('r'));
        final fs = [for (var i = 0; i < 3; i++) _frame('f$i', 'r', i)];
        await repo.saveFrames(fs);
        // shift positions: f0 -> 1, f1 -> 2, f2 -> 3, insert new at 0
        await repo.saveFrames([
          for (final f in fs) f.copyWith(position: f.position + 1),
          _frame('new', 'r', 0),
        ]);
        final got = await repo.frames('r');
        expect(got.map((f) => f.id), ['new', 'f0', 'f1', 'f2']);
        expect(got.map((f) => f.position), [0, 1, 2, 3]);
      });

      test('readings newest first', () async {
        SavedReading r(String id, DateTime t) => SavedReading(
          id: id,
          bodyId: 'canon-a1',
          bodyMake: 'Canon',
          bodyModel: 'A-1',
          format: FilmFormat.f135,
          exposure: _full,
          takenAt: t,
          utcOffsetMinutes: -60,
          note: 'n',
          location: const GeoFix(latitude: 1, longitude: 2, accuracy: 3),
          snapshot: 's.jpg',
          updatedAt: t,
        );
        final old = r('old', _t0);
        final mid = r('mid', _t0.add(const Duration(hours: 1)));
        final recent = r('new', _t0.add(const Duration(days: 1)));
        await repo.saveReading(mid);
        await repo.saveReading(recent);
        await repo.saveReading(old);
        final got = await repo.readings();
        expect(got.map((x) => x.id), ['new', 'mid', 'old']);
        expect(got.first, recent);
        await repo.deleteReading('mid');
        expect((await repo.readings()).map((x) => x.id), ['new', 'old']);
      });

      test('UTC sub-second times with an offset round-trip equal', () async {
        final t = DateTime.utc(2026, 11, 21, 10, 0, 5, 678, 912);
        final whole = DateTime.utc(2026, 11, 21, 10, 0, 5);
        await repo.saveRoll(_roll('r').copyWith(startedAt: t, updatedAt: t));
        final f = _frame('f', 'r', 0).copyWith(
          takenAt: () => t,
          utcOffsetMinutes: () => -330,
          updatedAt: t,
        );
        await repo.saveFrames([f]);
        final s = SavedReading(
          id: 's',
          format: FilmFormat.f135,
          exposure: Exposure.blank,
          takenAt: t,
          utcOffsetMinutes: 330,
          updatedAt: t,
        );
        await repo.saveReading(s);
        final roll = (await repo.rolls()).single;
        expect(roll.startedAt, whole);
        expect(roll.startedAt.isUtc, isTrue);
        final got = (await repo.frames('r')).single;
        expect(got.takenAt, whole);
        expect(got.utcOffsetMinutes, -330);
        // a reloaded value saves and reloads unchanged
        await repo.saveFrames([got]);
        expect((await repo.frames('r')).single, got);
        final reading = (await repo.readings()).single;
        expect(reading.takenAt, whole);
        expect(reading.utcOffsetMinutes, 330);
        expect(reading.takenAt.isUtc, isTrue);
      });

      test('transaction returns the action result', () async {
        final v = await repo.transaction(() async {
          await repo.saveRoll(_roll('r'));
          return 7;
        });
        expect(v, 7);
        expect(await repo.rolls(), hasLength(1));
      });
    });
  }

  group('drift only', () {
    test(
      'rows with unknown enum values or missing offsets are skipped',
      () async {
        final db = GrainDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = DriftRollRepository(db);
        await repo.saveRoll(_roll('good'));
        await repo.saveRoll(_roll('bad', number: 2));
        await db.customStatement(
          "UPDATE rolls SET status = 'bogus' WHERE id = 'bad'",
        );
        expect((await repo.rolls()).map((r) => r.id), ['good']);

        await repo.saveFrames([
          _frame('f0', 'good', 0),
          _frame('f1', 'good', 1).copyWith(exposure: _full),
          _frame('f2', 'good', 2).copyWith(exposure: _full),
        ]);
        await db.customStatement(
          "UPDATE frames SET mode = 'bogus' WHERE id = 'f1'",
        );
        await db.customStatement(
          "UPDATE frames SET area = 'bogus' WHERE id = 'f2'",
        );
        expect((await repo.frames('good')).map((f) => f.id), ['f0']);

        SavedReading r(String id) => SavedReading(
          id: id,
          format: FilmFormat.f135,
          exposure: _full,
          takenAt: _t0,
          utcOffsetMinutes: 60,
          updatedAt: _t0,
        );
        for (final id in ['ok', 'badmode', 'nooffset']) {
          await repo.saveReading(r(id));
        }
        await db.customStatement(
          "UPDATE saved_readings SET mode = 'bogus' WHERE id = 'badmode'",
        );
        await db.customStatement(
          "UPDATE saved_readings SET utc_offset_minutes = NULL WHERE id = 'nooffset'",
        );
        expect((await repo.readings()).map((x) => x.id), ['ok']);
      },
    );
  });
}
