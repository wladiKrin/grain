import 'package:flutter_test/flutter_test.dart';
import 'package:grain/backup/backup.dart';
import 'package:grain/backup/merge.dart' show finishTimeFor;
import 'package:grain/gear/model.dart';
import 'package:grain/rolls/model.dart';

final t0 = DateTime.utc(2026, 1, 1, 10);
const snapA = '11111111-1111-4111-8111-111111111111.jpg';

Roll roll(
  String id, {
  RollStatus status = RollStatus.finished,
  String notes = '',
  String? bodyId = 'canon-a1',
  DateTime? finishedAt,
}) => Roll(
  id: id,
  number: 1,
  filmStock: 'Ilford HP5 Plus',
  filmType: FilmType.bwNeg,
  boxIso: 400,
  pushThirds: 0,
  bodyId: bodyId,
  bodyMake: 'Canon',
  bodyModel: 'A-1',
  format: FilmFormat.f135,
  size: 36,
  startFrame: StartFrame.one,
  notes: notes,
  status: status,
  startedAt: t0,
  finishedAt: status == RollStatus.finished ? (finishedAt ?? t0) : null,
  updatedAt: t0,
);

Frame frame(
  String id,
  String rollId,
  int i, {
  String? snapshot,
  String? lensId,
  DateTime? takenAt,
}) => Frame(
  id: id,
  rollId: rollId,
  position: i,
  number: i + 1,
  exposure: Exposure(aperture: 8, shutter: '1/125', lensId: lensId),
  takenAt: takenAt ?? t0.add(Duration(minutes: i)),
  utcOffsetMinutes: 60,
  snapshot: snapshot,
  updatedAt: t0,
);

SavedReading reading(String id, {String? note, String? snapshot}) =>
    SavedReading(
      id: id,
      format: FilmFormat.f135,
      exposure: const Exposure(aperture: 4, shutter: '1/60'),
      takenAt: t0,
      utcOffsetMinutes: 60,
      note: note,
      snapshot: snapshot,
      updatedAt: t0,
    );

String Function() ids() {
  var n = 0;
  return () => 'new-${++n}';
}

MergePlan plan({
  List<(Roll, List<Frame>)> localRolls = const [],
  List<SavedReading> localReadings = const [],
  List<(Roll, List<Frame>)> rolls = const [],
  List<SavedReading> readings = const [],
  Set<String> snapshotNames = const {},
  Map<String, String> profileIds = const {},
  Map<String, bool> localSnapshots = const {},
}) => planMerge(
  localRolls: localRolls,
  localReadings: localReadings,
  incoming: BackupContents(
    rolls: rolls,
    readings: readings,
    snapshotNames: snapshotNames,
  ),
  profileIds: profileIds,
  newId: ids(),
  localSnapshots: localSnapshots,
);

void main() {
  test('identical roll is skipped', () {
    final r = (roll('r1'), [frame('f1', 'r1', 0), frame('f2', 'r1', 1)]);
    final p = plan(localRolls: [r], rolls: [r]);
    expect(p.rolls, isEmpty);
    expect(p.report.rollsSkipped, 1);
    expect(p.report.rollsAdded, 0);
    expect(p.report.rollsCopied, 0);
  });

  test('a roll differing only in active/finished counts as identical', () {
    final frames = [frame('f1', 'r1', 0)];
    final p = plan(
      localRolls: [
        (roll('r1', finishedAt: t0.add(const Duration(days: 3))), frames),
      ],
      rolls: [(roll('r1', status: RollStatus.active), frames)],
    );
    expect(p.rolls, isEmpty);
    expect(p.report.rollsSkipped, 1);
    final q = plan(
      localRolls: [(roll('r1', status: RollStatus.active), frames)],
      rolls: [(roll('r1'), frames)],
    );
    expect(q.rolls, isEmpty);
    expect(q.report.rollsSkipped, 1);
  });

  test('same id, different content → kept as a copy with new ids', () {
    final local = (roll('r1'), [frame('f1', 'r1', 0), frame('f2', 'r1', 1)]);
    final incoming = (
      roll('r1', notes: 'pushed in Rodinal'),
      [frame('f1', 'r1', 0), frame('f2', 'r1', 1)],
    );
    final p = plan(localRolls: [local], rolls: [incoming]);
    expect(p.report.rollsCopied, 1);
    expect(p.rolls, hasLength(1));
    final (copy, frames) = p.rolls.single;
    expect(copy.id, isNot('r1'));
    expect(copy.notes, 'pushed in Rodinal');
    expect(frames, hasLength(2));
    for (final f in frames) {
      expect(f.id, isNot(anyOf('f1', 'f2')));
      expect(f.rollId, copy.id);
    }
    expect(frames.map((f) => f.id).toSet(), hasLength(2));
    expect(frames.map((f) => f.number), [1, 2]);
  });

  test('a changed reading is kept as a copy', () {
    final p = plan(
      localReadings: [reading('s1')],
      readings: [reading('s1', note: 'by the river')],
    );
    expect(p.report.readingsCopied, 1);
    expect(p.readings.single.id, isNot('s1'));
    expect(p.readings.single.note, 'by the river');
  });

  test('new roll and reading are added', () {
    final p = plan(
      localRolls: [
        (roll('r1'), [frame('f1', 'r1', 0)]),
      ],
      localReadings: [reading('s1')],
      rolls: [
        (roll('r2'), [frame('f2', 'r2', 0)]),
      ],
      readings: [reading('s1'), reading('s2')],
    );
    expect(p.report.rollsAdded, 1);
    expect(p.report.readingsAdded, 1);
    expect(p.report.readingsSkipped, 1);
    expect(p.rolls.single.$1.id, 'r2');
    expect(p.rolls.single.$2.single.id, 'f2');
    expect(p.readings.single.id, 's2');
  });

  test('a new roll whose frame id is taken here gets a fresh frame id', () {
    final p = plan(
      localRolls: [
        (roll('r1'), [frame('f1', 'r1', 0)]),
      ],
      rolls: [
        (roll('r2'), [frame('f1', 'r2', 0)]),
      ],
    );
    expect(p.rolls.single.$2.single.id, isNot('f1'));
    expect(p.rolls.single.$2.single.rollId, 'r2');
  });

  test('imported active roll becomes finished when one is active here', () {
    final last = t0.add(const Duration(minutes: 1));
    final p = plan(
      localRolls: [(roll('r1', status: RollStatus.active), <Frame>[])],
      rolls: [
        (
          roll('r2', status: RollStatus.active),
          [frame('f1', 'r2', 0), frame('f2', 'r2', 1, takenAt: last)],
        ),
      ],
    );
    final (r, _) = p.rolls.single;
    expect(r.status, RollStatus.finished);
    expect(r.finishedAt, last);
    expect(p.report.rollsDeactivated, 1);
    expect(p.report.rollsAdded, 1);
  });

  test('with no active roll here only one imported roll stays active', () {
    final p = plan(
      rolls: [
        (roll('r1', status: RollStatus.active), <Frame>[]),
        (roll('r2', status: RollStatus.active), <Frame>[]),
      ],
    );
    expect(p.rolls.where((r) => r.$1.isActive), hasLength(1));
    expect(p.rolls.firstWhere((r) => !r.$1.isActive).$1.finishedAt, t0);
    expect(p.report.rollsDeactivated, 1);
  });

  test('profile renames reach roll body and frame lens ids', () {
    final p = plan(
      rolls: [
        (roll('r1', bodyId: 'my-a1'), [frame('f1', 'r1', 0, lensId: 'my-50')]),
      ],
      profileIds: {'body:my-a1': 'my-a1-2', 'lens:my-50': 'my-50-2'},
    );
    final (r, frames) = p.rolls.single;
    expect(r.bodyId, 'my-a1-2');
    expect(frames.single.exposure.lensId, 'my-50-2');
  });

  test('a remapped roll identical to the one here is skipped', () {
    final here = (
      roll('r1', bodyId: 'my-a1-2'),
      [frame('f1', 'r1', 0, lensId: 'my-50-2')],
    );
    final p = plan(
      localRolls: [here],
      rolls: [
        (roll('r1', bodyId: 'my-a1'), [frame('f1', 'r1', 0, lensId: 'my-50')]),
      ],
      profileIds: {'body:my-a1': 'my-a1-2', 'lens:my-50': 'my-50-2'},
    );
    expect(p.rolls, isEmpty);
    expect(p.report.rollsSkipped, 1);
  });

  test('a snapshot name taken by different bytes is renamed', () {
    final p = plan(
      rolls: [
        (roll('r1'), [frame('f1', 'r1', 0, snapshot: snapA)]),
      ],
      readings: [reading('s1', snapshot: snapA)],
      snapshotNames: {snapA},
      localSnapshots: {snapA: false},
    );
    final target = p.snapshots[snapA]!;
    expect(target, isNot(snapA));
    expect(target, matches(r'\.jpg$'));
    expect(p.rolls.single.$2.single.snapshot, target);
    expect(p.readings.single.snapshot, target);
    expect(p.report.snapshotsAdded, 1);
  });

  test('a free snapshot name is copied as is; identical bytes are reused', () {
    final p = plan(
      rolls: [
        (roll('r1'), [frame('f1', 'r1', 0, snapshot: snapA)]),
      ],
      snapshotNames: {snapA},
    );
    expect(p.snapshots, {snapA: snapA});
    expect(p.rolls.single.$2.single.snapshot, snapA);
    expect(p.report.snapshotsAdded, 1);
    final q = plan(
      rolls: [
        (roll('r1'), [frame('f1', 'r1', 0, snapshot: snapA)]),
      ],
      snapshotNames: {snapA},
      localSnapshots: {snapA: true},
    );
    expect(q.snapshots, isEmpty);
    expect(q.rolls.single.$2.single.snapshot, snapA);
    expect(q.report.snapshotsAdded, 0);
  });

  test('a copy never shares a snapshot file with the original', () {
    final p = plan(
      localRolls: [
        (roll('r1'), [frame('f1', 'r1', 0, snapshot: snapA)]),
      ],
      rolls: [
        (roll('r1', notes: 'x'), [frame('f1', 'r1', 0, snapshot: snapA)]),
      ],
      snapshotNames: {snapA},
      localSnapshots: {snapA: true},
    );
    final target = p.snapshots[snapA]!;
    expect(target, isNot(snapA));
    expect(p.rolls.single.$2.single.snapshot, target);
  });

  test('summary text', () {
    expect(
      const ImportReport(
        rollsAdded: 3,
        readingsAdded: 12,
        profilesAdded: 2,
        rollsCopied: 1,
        rollsSkipped: 5,
        rollsDeactivated: 1,
      ).summary,
      'Added 3 rolls, 12 saved readings, 2 profiles. Kept 1 as a copy because it differs from what is here. '
      'Skipped 5 already on this phone. 1 imported active roll is now finished.',
    );
    expect(
      const ImportReport(rollsAdded: 1).summary,
      'Added 1 roll, 0 saved readings, 0 profiles.',
    );
    expect(
      const ImportReport(
        readingsAdded: 1,
        profilesAdded: 1,
        rollsCopied: 1,
        readingsCopied: 1,
        profilesCopied: 1,
        readingsSkipped: 2,
        rollsDeactivated: 2,
      ).summary,
      'Added 0 rolls, 1 saved reading, 1 profile. Kept 3 as copies because they differ from what is here. '
      'Skipped 2 already on this phone. 2 imported active rolls are now finished.',
    );
  });

  test(
    'a roll finished here since (status, finishedAt, updatedAt) is identical',
    () {
      final frames = [frame('f1', 'r1', 0)];
      final later = t0.add(const Duration(days: 2));
      final p = plan(
        localRolls: [
          (roll('r1', finishedAt: later).copyWith(updatedAt: later), frames),
        ],
        rolls: [(roll('r1', status: RollStatus.active), frames)],
      );
      expect(p.rolls, isEmpty);
      expect(p.report.rollsSkipped, 1);
      // Both finished, at different times: a real difference.
      final q = plan(
        localRolls: [
          (roll('r1', finishedAt: later).copyWith(updatedAt: later), frames),
        ],
        rolls: [(roll('r1'), frames)],
      );
      expect(q.report.rollsCopied, 1);
    },
  );

  test('a copy stored by an earlier import is recognised', () {
    final original = (roll('r1'), [frame('f1', 'r1', 0, snapshot: snapA)]);
    final edited = (
      roll('r1', notes: 'x'),
      [frame('f1', 'r1', 0, snapshot: snapA)],
    );
    final earlierCopy = (
      roll('c1', notes: 'x'),
      [
        frame(
          'c1-f',
          'c1',
          0,
          snapshot: '22222222-2222-4222-8222-222222222222.jpg',
        ),
      ],
    );
    final p = plan(
      localRolls: [original, earlierCopy],
      localReadings: [
        reading('s1'),
        reading('s2', note: 'edited'),
      ],
      rolls: [edited],
      readings: [reading('s1', note: 'edited')],
      snapshotNames: {snapA},
      localSnapshots: {
        snapA: true,
        '22222222-2222-4222-8222-222222222222.jpg': false,
      },
    );
    expect(p.rolls, isEmpty);
    expect(p.readings, isEmpty);
    expect(p.report.rollsSkipped, 1);
    expect(p.report.readingsSkipped, 1);
    expect(p.snapshots, isEmpty);
  });

  test('skipped records get their missing snapshot files back', () {
    const renamed = '33333333-3333-4333-8333-333333333333.jpg';
    final p = plan(
      localRolls: [
        (roll('r1'), [frame('f1', 'r1', 0, snapshot: snapA)]),
      ],
      localReadings: [reading('s1', snapshot: renamed)],
      rolls: [
        (roll('r1'), [frame('f1', 'r1', 0, snapshot: snapA)]),
      ],
      readings: [reading('s1', snapshot: snapA)],
      snapshotNames: {snapA},
    );
    expect(p.report.rollsSkipped, 1);
    expect(p.report.readingsSkipped, 1);
    expect(p.restores, {snapA: snapA, renamed: snapA});
    expect(p.snapshots, isEmpty);
    expect(p.report.snapshotsAdded, 2);
    // Files that are here are left alone.
    final q = plan(
      localRolls: [
        (roll('r1'), [frame('f1', 'r1', 0, snapshot: snapA)]),
      ],
      rolls: [
        (roll('r1'), [frame('f1', 'r1', 0, snapshot: snapA)]),
      ],
      snapshotNames: {snapA},
      localSnapshots: {snapA: false},
    );
    expect(q.restores, isEmpty);
  });

  test('a finished time is the latest frame time, not the last position', () {
    final late = t0.add(const Duration(hours: 5));
    expect(
      finishTimeFor(roll('r1'), [
        frame('a', 'r1', 0, takenAt: late),
        frame('b', 'r1', 1, takenAt: t0),
      ]),
      late,
    );
    expect(finishTimeFor(roll('r1'), const []), t0);
  });
}
