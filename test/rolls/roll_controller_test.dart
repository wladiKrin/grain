import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/roll_repository.dart';
import 'package:grain/rolls/snapshot_store.dart';
import 'package:grain/settings/settings.dart';

import '../support/fake_location.dart';

Body body(String id, String model) => Body(
  id: id,
  make: 'Canon',
  model: model,
  mount: 'FD',
  format: FilmFormat.f135,
  frames: 36,
  shutter: const ['1/125'],
);

void main() {
  late Directory tmp;
  late SnapshotStore store;
  late Settings settings;
  late MemoryRollRepository repo;
  late FakeLocation loc;
  late List<Completer<String?>> snaps;
  late RollController rolls;
  var ids = 0;
  const e = Exposure(mode: MeterMode.aperturePriority, aperture: 8, iso: 400);

  Future<Roll> start({
    StartFrame sf = StartFrame.one,
    Body? b,
    int size = 36,
  }) => rolls.startRoll(
    filmStock: 'HP5',
    filmType: FilmType.bwNeg,
    boxIso: 400,
    pushThirds: 0,
    body: b ?? body('a1', 'A-1'),
    size: size,
    startFrame: sf,
  );

  RollController make() => RollController(
    repository: repo,
    snapshots: store,
    settings: settings,
    takeSnapshot: (id) {
      final c = Completer<String?>();
      snaps.add(c);
      return c.future;
    },
    location: loc,
    now: () => DateTime.utc(2026, 11, 21, 13, 3, 22, 456),
    newId: () => 'id${ids++}',
  );

  setUp(() async {
    ids = 0;
    tmp = Directory.systemTemp.createTempSync('grain_snaps');
    store = SnapshotStore(tmp);
    settings = Settings.inMemory();
    repo = MemoryRollRepository();
    loc = FakeLocation();
    snaps = [];
    rolls = make();
    await rolls.load();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('starting a roll numbers it and finishes the active one', () async {
    final a = await start();
    expect(a.number, 1);
    expect(rolls.active!.id, a.id);
    final b = await start();
    expect(b.number, 2);
    expect(rolls.active!.id, b.id);
    final first = rolls.rolls.last;
    expect(first.status, RollStatus.finished);
    expect(first.finishedAt, DateTime.utc(2026, 11, 21, 13, 3, 22));
    expect(rolls.rolls.map((r) => r.number), [2, 1]);
    final stored = await repo.rolls();
    expect(stored.map((r) => r.status), [
      RollStatus.finished,
      RollStatus.active,
    ]);
    expect(rolls.latest!.number, 2);
  });

  test('logging is instant: memory updates before the first await', () async {
    final roll = await start();
    final f = rolls.logFrame(e);
    expect(rolls.activeFrames.single.label, '1');
    expect(rolls.nextLabel, '2');
    final frame = await f;
    expect(frame.snapshot, isNull);
    expect(frame.takenAt, DateTime.utc(2026, 11, 21, 13, 3, 22));
    expect(frame.utcOffsetMinutes, isNotNull);
    snaps.single.complete('${store.dir.path}/abc.jpg');
    await pumpEventQueue();
    expect(rolls.activeFrames.single.snapshot, 'abc.jpg');
    expect((await repo.frames(roll.id)).single.snapshot, 'abc.jpg');
  });

  test('two quick logs get consecutive numbers', () async {
    final roll = await start();
    unawaited(rolls.logFrame(e));
    unawaited(rolls.logFrame(e));
    expect(rolls.activeFrames.map((f) => f.label), ['1', '2']);
    await pumpEventQueue();
    expect((await repo.frames(roll.id)).map((f) => f.label), ['1', '2']);
  });

  test('a snapshot for a deleted frame removes the file', () async {
    final roll = await start();
    final frame = await rolls.logFrame(e);
    final file = store.file('abc.jpg')..writeAsBytesSync([1]);
    await rolls.deleteFrame(roll.id, frame.id);
    snaps.single.complete(file.path);
    await pumpEventQueue();
    expect(file.existsSync(), isFalse);
    expect(rolls.activeFrames, isEmpty);
    expect(await repo.frames(roll.id), isEmpty);
  });

  test('a late snapshot keeps an edit made meanwhile', () async {
    final roll = await start();
    final frame = await rolls.logFrame(e);
    await rolls.updateFrame(frame.copyWith(note: () => 'tree'));
    snaps.single.complete('${store.dir.path}/abc.jpg');
    await pumpEventQueue();
    final f = rolls.activeFrames.single;
    expect(f.note, 'tree');
    expect(f.snapshot, 'abc.jpg');
    final s = (await repo.frames(roll.id)).single;
    expect(s.note, 'tree');
    expect(s.snapshot, 'abc.jpg');
  });

  test('snapshots off takes none; location off asks for none', () async {
    await settings.setSnapshots(false);
    await start();
    final frame = await rolls.logFrame(e);
    await pumpEventQueue();
    expect(snaps, isEmpty);
    expect(loc.calls, 0);
    expect(frame.location, isNull);
    expect(rolls.activeFrames.single.location, isNull);
  });

  test('location on stores the fix', () async {
    await settings.setLocation(true);
    const fix = GeoFix(latitude: 52.52, longitude: 13.405, accuracy: 1500);
    loc.fix = fix;
    final roll = await start();
    await rolls.logFrame(e);
    await pumpEventQueue();
    expect(rolls.activeFrames.single.location, fix);
    expect((await repo.frames(roll.id)).single.location, fix);
  });

  test('00 start, 36 frames: counter runs on past the size', () async {
    await start(sf: StartFrame.doubleZero);
    for (var i = 0; i < 38; i++) {
      await rolls.logFrame(e);
    }
    final labels = rolls.activeFrames.map((f) => f.label).toList();
    expect(labels.first, '00');
    expect(labels.last, '36');
    expect(rolls.nextLabel, '37');
    expect(rolls.nextOverrun, 1);
    await rolls.logFrame(e);
    expect(rolls.nextOverrun, 2);
  });

  test('insert, delete and renumber persist', () async {
    final roll = await start();
    for (var i = 0; i < 4; i++) {
      await rolls.logFrame(e);
    }
    Future<List<int>> nums() async =>
        (await repo.frames(roll.id)).map((f) => f.number).toList();
    await rolls.insertBlank(roll.id, 1);
    expect(await nums(), [1, 2, 3, 4, 5]);
    expect(rolls.activeFrames[1].exposure.isBlank, isTrue);
    await rolls.deleteFrame(roll.id, rolls.activeFrames[1].id);
    expect(await nums(), [1, 2, 3, 4]);
    await rolls.renumberFrom(roll.id, 0, 5);
    expect(await nums(), [5, 6, 7, 8]);
    expect(rolls.activeFrames.map((f) => f.number), [5, 6, 7, 8]);
  });

  test('logsFor follows the roll body', () async {
    final a1 = body('a1', 'A-1');
    await start(b: a1);
    expect(rolls.logsFor(a1), isTrue);
    expect(rolls.logsFor(body('ae1', 'AE-1')), isFalse);
    expect(rolls.logsFor(null), isFalse);
    await rolls.startRoll(
      filmStock: 'HP5',
      filmType: FilmType.bwNeg,
      boxIso: 400,
      pushThirds: 0,
      body: null,
      size: 36,
      startFrame: StartFrame.one,
    );
    expect(rolls.logsFor(null), isTrue);
    expect(rolls.logsFor(a1), isFalse);
    expect(rolls.active!.format, FilmFormat.f135);
  });

  test('save reading stores body, exposure and snapshot', () async {
    final a1 = body('a1', 'A-1');
    final r = await rolls.saveReading(e, body: a1, format: FilmFormat.f135);
    expect(rolls.readings.single.id, r.id);
    snaps.single.complete('${store.dir.path}/r.jpg');
    await pumpEventQueue();
    final s = (await repo.readings()).single;
    expect(s.bodyId, 'a1');
    expect(s.bodyModel, 'A-1');
    expect(s.exposure, e);
    expect(s.snapshot, 'r.jpg');
    expect(s.takenAt, DateTime.utc(2026, 11, 21, 13, 3, 22));
  });

  test('deleting a roll deletes its snapshot files', () async {
    final roll = await start();
    await rolls.logFrame(e);
    final file = store.file('abc.jpg')..writeAsBytesSync([1]);
    snaps.single.complete(file.path);
    await pumpEventQueue();
    await rolls.deleteRoll(roll.id);
    expect(file.existsSync(), isFalse);
    expect(rolls.rolls, isEmpty);
    expect(await repo.rolls(), isEmpty);
    expect(await repo.frames(roll.id), isEmpty);
  });

  test('undo of a log is deleteFrame of the last frame', () async {
    final roll = await start();
    final f = await rolls.logFrame(e);
    expect(rolls.nextLabel, '2');
    await rolls.deleteFrame(roll.id, f.id);
    expect(rolls.nextLabel, '1');
  });

  test(
    'a stale edit saved after a late attach keeps snapshot and fix',
    () async {
      await settings.setLocation(true);
      const fix = GeoFix(latitude: 1, longitude: 2);
      loc.fix = fix;
      final roll = await start();
      final stale = await rolls.logFrame(e); // editor opened now
      snaps.single.complete('${store.dir.path}/abc.jpg');
      await pumpEventQueue();
      await rolls.updateFrame(stale.copyWith(note: () => 'late'));
      final f = rolls.activeFrames.single;
      expect([f.note, f.snapshot, f.location], ['late', 'abc.jpg', fix]);
      final s = (await repo.frames(roll.id)).single;
      expect([s.note, s.snapshot, s.location], ['late', 'abc.jpg', fix]);
    },
  );

  test('editing a removed frame or reading writes nothing', () async {
    final roll = await start();
    final f = await rolls.logFrame(e);
    await rolls.deleteFrame(roll.id, f.id);
    await rolls.updateFrame(f.copyWith(note: () => 'x'));
    expect(await repo.frames(roll.id), isEmpty);
    final r = await rolls.saveReading(e, body: null, format: FilmFormat.f135);
    await rolls.deleteReading(r.id);
    await rolls.updateReading(r.copyWith(note: () => 'x'));
    expect(await repo.readings(), isEmpty);
    expect(rolls.readings, isEmpty);
  });

  test('quick undo then log keeps the new frame', () async {
    final roll = await start();
    final f = await rolls.logFrame(e);
    final undo = rolls.deleteFrame(roll.id, f.id);
    final log = rolls.logFrame(e);
    final ins = rolls.insertBlank(roll.id, 0);
    await Future.wait([undo, log, ins]);
    await pumpEventQueue();
    final mem = rolls.activeFrames.map((x) => x.number).toList();
    expect(mem, [1, 2]);
    expect((await repo.frames(roll.id)).map((x) => x.number), mem);
  });

  test('location turned off before the fix arrives drops it', () async {
    await settings.setLocation(true);
    loc.fix = const GeoFix(latitude: 1, longitude: 2);
    await start();
    final f = rolls.logFrame(e);
    await settings.setLocation(false);
    await f;
    await pumpEventQueue();
    expect(rolls.activeFrames.single.location, isNull);
  });

  test(
    'deleting the snapshot while pending discards the arriving file',
    () async {
      final roll = await start();
      final f = await rolls.logFrame(e);
      final file = store.file('abc.jpg')..writeAsBytesSync([1]);
      await rolls.deleteFrameSnapshot(roll.id, f.id);
      snaps.single.complete(file.path);
      await pumpEventQueue();
      expect(file.existsSync(), isFalse);
      expect(rolls.activeFrames.single.snapshot, isNull);
    },
  );
}
