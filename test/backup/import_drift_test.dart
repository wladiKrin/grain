import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/backup/backup.dart';
import 'package:grain/db/database.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/roll_repository.dart';
import 'package:grain/rolls/snapshot_store.dart';
import 'package:grain/settings/settings.dart';

/// Fails the [failAt]th frame write.
class _FailingRepository extends DriftRollRepository {
  _FailingRepository(super.db, {required this.failAt});
  final int failAt;
  int _calls = 0;

  @override
  Future<void> saveFrames(List<Frame> frames) {
    if (++_calls == failAt) throw StateError('disk full');
    return super.saveFrames(frames);
  }
}

final _t = DateTime.utc(2026, 10, 1, 12);

(Roll, List<Frame>) _roll(String id, int number) => (
  Roll(
    id: id,
    number: number,
    filmStock: 'Kodak Gold 200',
    filmType: FilmType.colorNeg,
    boxIso: 200,
    pushThirds: 0,
    format: FilmFormat.f135,
    size: 36,
    startFrame: StartFrame.one,
    status: RollStatus.finished,
    startedAt: _t,
    finishedAt: _t,
    updatedAt: _t,
  ),
  [
    for (var i = 0; i < 3; i++)
      Frame(
        id: '$id-f$i',
        rollId: id,
        position: i,
        number: i + 1,
        takenAt: _t,
        updatedAt: _t,
      ),
  ],
);

void main() {
  test('a failing write inside an import leaves nothing behind', () async {
    final db = GrainDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = Directory.systemTemp.createTempSync('grain-drift');
    addTearDown(() => dir.deleteSync(recursive: true));
    final repo = _FailingRepository(db, failAt: 2);
    final rolls = RollController(
      repository: repo,
      snapshots: SnapshotStore(dir),
      settings: Settings.inMemory(),
    );
    await rolls.load();
    final reading = SavedReading(
      id: 's1',
      format: FilmFormat.f135,
      exposure: const Exposure(aperture: 4),
      takenAt: _t,
      utcOffsetMinutes: 0,
      updatedAt: _t,
    );
    final plan = MergePlan(
      rolls: [_roll('a', 1), _roll('b', 2)],
      readings: [reading],
      snapshots: const {},
      report: const ImportReport(rollsAdded: 2, readingsAdded: 1),
    );
    await expectLater(rolls.importRecords(plan), throwsStateError);
    final plain = DriftRollRepository(db);
    expect(await plain.rolls(), isEmpty);
    expect(await plain.frames('a'), isEmpty);
    expect(await plain.readings(), isEmpty);

    // The same plan through a working repository stores everything.
    final ok = RollController(
      repository: plain,
      snapshots: SnapshotStore(dir),
      settings: Settings.inMemory(),
    );
    await ok.load();
    await ok.importRecords(plan);
    expect((await plain.rolls()).map((r) => r.id), ['a', 'b']);
    expect(await plain.frames('b'), hasLength(3));
    expect(await plain.readings(), hasLength(1));
  });
}
