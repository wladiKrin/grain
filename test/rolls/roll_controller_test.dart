import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/backup/merge.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/roll_repository.dart';
import 'package:grain/rolls/snapshot_store.dart';
import 'package:grain/settings/settings.dart';

import '../support/fake_location.dart';
import 'support.dart' show roll;

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

  test('a skipped frame is a blank with the time, camera, lens and '
      'location, and no snapshot', () async {
    await settings.setLocation(true);
    const fix = GeoFix(latitude: 52.52, longitude: 13.405);
    loc.fix = fix;
    final roll = await start();
    await rolls.logFrame(e);
    final pending = rolls.skipFrame(
      lens: const Exposure(
        lensId: 'fd-50',
        lensMake: 'Canon',
        lensName: 'FD 50mm f/1.8',
        focal: 50,
        // Only the lens is kept.
        iso: 400,
        aperture: 8,
      ),
    );
    expect(rolls.activeFrames.map((f) => f.label), ['1', '2']);
    expect(rolls.nextLabel, '3');
    final f = await pending;
    await pumpEventQueue();
    // Only the logged frame asked for a snapshot.
    expect(snaps, hasLength(1));
    expect(f.number, 2);
    expect(f.takenAt, DateTime.utc(2026, 11, 21, 13, 3, 22));
    expect(f.utcOffsetMinutes, isNotNull);
    expect(f.bodyId, 'a1');
    expect(f.bodyModel, 'A-1');
    expect(f.exposure.lensName, 'FD 50mm f/1.8');
    expect(f.exposure.focal, 50);
    expect(f.exposure.iso, isNull);
    expect(f.exposure.aperture, isNull);
    expect(f.exposure.mode, isNull);
    expect(f.exposure.hasNoValues, isTrue);
    expect(f.exposure.isBlank, isFalse);
    final stored = (await repo.frames(roll.id)).last;
    expect(stored.location, fix);
    expect(stored.snapshot, isNull);
    expect(stored.exposure, f.exposure);
    // Undo is a delete, as for a logged frame.
    await rolls.deleteFrame(roll.id, f.id);
    expect(rolls.nextLabel, '2');
  });

  test('a skip without a lens is fully blank', () async {
    await start();
    final f = await rolls.skipFrame();
    expect(f.exposure.isBlank, isTrue);
    expect(f.takenAt, isNotNull);
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

  group('cameras', () {
    final a1 = body('a1', 'A-1');
    final ae1 = body('ae1', 'AE-1');
    final f1 = body('f1', 'F-1');

    List<String?> cams() => [for (final f in rolls.activeFrames) f.bodyId];

    test('a logged frame records the camera it was logged with', () async {
      final roll = await start(b: a1);
      final f = await rolls.logFrame(e);
      expect(f.bodyId, 'a1');
      expect(f.bodyName, 'Canon A-1');
      expect((await repo.frames(roll.id)).single.bodyId, 'a1');
    });

    test('continuing in another camera changes only the next frames', () async {
      final roll = await start(b: a1);
      await rolls.logFrame(e);
      await rolls.logFrame(e);
      await rolls.continueRoll(roll.id, ae1);
      expect(rolls.active!.bodyId, 'ae1');
      expect(rolls.active!.bodyName, 'Canon AE-1');
      expect(cams(), ['a1', 'a1']);
      expect(rolls.logsFor(ae1), isTrue);
      expect(rolls.logsFor(a1), isFalse);
      await rolls.logFrame(e);
      expect(cams(), ['a1', 'a1', 'ae1']);
      expect([for (final f in await repo.frames(roll.id)) f.bodyId], cams());
      expect((await repo.rolls()).single.bodyId, 'ae1');
    });

    test('roll cameras: one, two in order, and a count beyond', () async {
      final roll = await start(b: a1);
      await rolls.logFrame(e);
      expect(rolls.camerasLabelOf(rolls.active!), 'Canon A-1');
      expect(isMultiCamera(rolls.active!, rolls.activeFrames), isFalse);
      // Loaded in another camera, nothing shot there yet: two cameras.
      await rolls.continueRoll(roll.id, ae1);
      expect(rolls.camerasLabelOf(rolls.active!), 'Canon A-1 → Canon AE-1');
      expect(isMultiCamera(rolls.active!, rolls.activeFrames), isTrue);
      await rolls.logFrame(e);
      await rolls.continueRoll(roll.id, f1);
      await rolls.logFrame(e);
      expect(rolls.camerasLabelOf(rolls.active!), '3 cameras');
      expect(
        [for (final c in rollCameras(rolls.active!, rolls.activeFrames)) c.id],
        ['a1', 'ae1', 'f1'],
      );
    });

    test('an inserted blank takes the camera of the frame before', () async {
      final roll = await start(b: a1);
      await rolls.logFrame(e);
      await rolls.continueRoll(roll.id, ae1);
      await rolls.logFrame(e);
      await rolls.continueRoll(roll.id, f1);
      // After frame 1 (A-1), at the start (the roll's F-1), at the end (AE-1).
      await rolls.insertBlank(roll.id, 1);
      expect(cams(), ['a1', 'a1', 'ae1']);
      await rolls.insertBlank(roll.id, 0);
      expect(cams(), ['f1', 'a1', 'a1', 'ae1']);
      await rolls.insertBlank(roll.id, 4);
      expect(cams(), ['f1', 'a1', 'a1', 'ae1', 'ae1']);
      expect(rolls.activeFrames[0].bodyName, 'Canon F-1');
    });

    test(
      'correcting the roll camera moves the frames that were on it',
      () async {
        final roll = await start(b: a1);
        await rolls.logFrame(e);
        final elsewhere = await rolls.logFrame(e);
        await rolls.updateFrame(
          elsewhere.copyWith(
            bodyId: () => 'f1',
            bodyMake: 'Canon',
            bodyModel: 'F-1',
          ),
        );
        await rolls.logFrame(e);
        await rolls.updateRoll(
          rolls.active!.copyWith(
            bodyId: () => 'ae1',
            bodyMake: 'Canon',
            bodyModel: 'AE-1',
          ),
        );
        expect(rolls.active!.bodyId, 'ae1');
        // The frame explicitly on the F-1 stays there.
        expect(cams(), ['ae1', 'f1', 'ae1']);
        expect(rolls.activeFrames.first.bodyName, 'Canon AE-1');
        expect([for (final f in await repo.frames(roll.id)) f.bodyId], cams());
        expect((await repo.rolls()).single.bodyId, 'ae1');
      },
    );

    test('an edit that keeps the camera leaves the frames alone', () async {
      final roll = await start(b: a1);
      await rolls.logFrame(e);
      await rolls.continueRoll(roll.id, ae1);
      await rolls.updateRoll(rolls.active!.copyWith(notes: 'n'));
      expect(cams(), ['a1']);
      expect(rolls.active!.notes, 'n');
    });

    test('correcting a roll whose frames are not loaded yet', () async {
      final roll = await start(b: a1);
      await rolls.logFrame(e);
      final again = make();
      await again.load();
      await again.finishRoll(roll.id);
      final other = make();
      await other.load();
      final r = other.rolls.single;
      await other.updateRoll(
        r.copyWith(bodyId: () => 'ae1', bodyMake: 'Canon', bodyModel: 'AE-1'),
      );
      expect((await repo.frames(roll.id)).single.bodyId, 'ae1');
      other.dispose();
      again.dispose();
    });
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

  test('remove location on a frame and a reading persists', () async {
    await settings.setLocation(true);
    loc.fix = const GeoFix(latitude: 1, longitude: 2);
    final roll = await start();
    final f = await rolls.logFrame(e);
    final r = await rolls.saveReading(e, body: null, format: FilmFormat.f135);
    await pumpEventQueue();
    expect(rolls.activeFrames.single.location, isNotNull);
    expect(rolls.readings.single.location, isNotNull);
    await rolls.deleteFrameLocation(roll.id, f.id);
    await rolls.deleteReadingLocation(r.id);
    expect(rolls.activeFrames.single.location, isNull);
    expect(rolls.readings.single.location, isNull);
    expect((await repo.frames(roll.id)).single.location, isNull);
    expect((await repo.readings()).single.location, isNull);
  });

  test('a location removed while in flight is not attached', () async {
    await settings.setLocation(true);
    final gate = Completer<GeoFix?>();
    final slow = _SlowLocation(gate.future);
    rolls = RollController(
      repository: repo,
      snapshots: store,
      settings: settings,
      location: slow,
      now: () => DateTime.utc(2026, 11, 21, 13, 3, 22),
      newId: () => 'id${ids++}',
    );
    await rolls.load();
    final roll = await start();
    final f = await rolls.logFrame(e);
    final r = await rolls.saveReading(e, body: null, format: FilmFormat.f135);
    await rolls.deleteFrameLocation(roll.id, f.id);
    await rolls.deleteReadingLocation(r.id);
    gate.complete(const GeoFix(latitude: 1, longitude: 2));
    await pumpEventQueue();
    expect(rolls.activeFrames.single.location, isNull);
    expect(rolls.readings.single.location, isNull);
    expect((await repo.frames(roll.id)).single.location, isNull);
  });
  test(
    'late snapshots and locations landing during an import stay in memory',
    () async {
      await settings.setLocation(true);
      final fixGate = Completer<GeoFix?>();
      final gated = _GatedRepository();
      repo = gated;
      rolls = RollController(
        repository: gated,
        snapshots: store,
        settings: settings,
        takeSnapshot: (id) {
          final c = Completer<String?>();
          snaps.add(c);
          return c.future;
        },
        location: _SlowLocation(fixGate.future),
        now: () => DateTime.utc(2026, 11, 21, 13, 3, 22),
        newId: () => 'id${ids++}',
      );
      await rolls.load();
      final roll = await start();
      final f = await rolls.logFrame(e);
      final r = await rolls.saveReading(e, body: null, format: FilmFormat.f135);
      expect(snaps, hasLength(2));
      final t = DateTime.utc(2026, 10, 1, 12);
      final incoming = SavedReading(
        id: 'imported',
        format: FilmFormat.f135,
        exposure: e,
        takenAt: t,
        utcOffsetMinutes: 0,
        updatedAt: t,
      );
      // The reload after the import's write is held while the attaches land.
      gated.hold = Completer<void>();
      final import = rolls.importRecords(
        MergePlan(
          rolls: const [],
          readings: [incoming],
          snapshots: const {},
          report: const ImportReport(readingsAdded: 1),
        ),
      );
      await gated.entered.future;
      snaps[0].complete('${store.dir.path}/frame.jpg');
      snaps[1].complete('${store.dir.path}/reading.jpg');
      const fix = GeoFix(latitude: 1, longitude: 2);
      fixGate.complete(fix);
      await pumpEventQueue();
      gated.hold!.complete();
      await import;

      final here = rolls.readings.firstWhere((x) => x.id == r.id);
      expect(here.snapshot, 'reading.jpg');
      expect(here.location, fix);
      expect(rolls.readings.map((x) => x.id), [r.id, 'imported']);
      expect(rolls.activeFrames.single.snapshot, 'frame.jpg');
      expect(rolls.activeFrames.single.location, fix);

      // A later edit keeps the attachments on disk too.
      await rolls.updateReading(here.copyWith(note: () => 'edited'));
      await rolls.updateFrame(f.copyWith(note: () => 'edited'));
      final stored = (await repo.readings()).firstWhere((x) => x.id == r.id);
      expect(stored.snapshot, 'reading.jpg');
      expect(stored.location, fix);
      expect(stored.note, 'edited');
      final frame = (await repo.frames(roll.id)).single;
      expect(frame.snapshot, 'frame.jpg');
      expect(frame.location, fix);
    },
  );

  test('a record deleted while an import reloads stays deleted', () async {
    final gated = _GatedRepository();
    repo = gated;
    rolls = make();
    await rolls.load();
    final mine = await rolls.saveReading(
      e,
      body: null,
      format: FilmFormat.f135,
    );
    final t = DateTime.utc(2026, 10, 1, 12);
    gated.hold = Completer<void>();
    final import = rolls.importRecords(
      MergePlan(
        rolls: const [],
        readings: [
          SavedReading(
            id: 'imported',
            format: FilmFormat.f135,
            exposure: e,
            takenAt: t,
            utcOffsetMinutes: 0,
            updatedAt: t,
          ),
        ],
        snapshots: const {},
        report: const ImportReport(readingsAdded: 1),
      ),
    );
    await gated.entered.future;
    final deleted = rolls.deleteReading(mine.id);
    gated.hold!.complete();
    await import;
    await deleted;
    expect(rolls.readings.map((x) => x.id), ['imported']);
  });

  test('a roll started during an import leaves one active roll', () async {
    final gated = _GatedRepository();
    repo = gated;
    rolls = make();
    await rolls.load();
    final x = roll();
    gated.hold = Completer<void>();
    final import = rolls.importRecords(
      MergePlan(
        rolls: [(x, const <Frame>[])],
        readings: const [],
        snapshots: const {},
        report: const ImportReport(rollsAdded: 1),
      ),
    );
    await gated.entered.future;
    final started = start();
    gated.hold!.complete();
    expect(await import, 1);
    final y = await started;
    expect(rolls.rolls.where((r) => r.isActive).map((r) => r.id), [y.id]);
    expect(
      rolls.rolls.firstWhere((r) => r.id == x.id).status,
      RollStatus.finished,
    );
    final fresh = make();
    await fresh.load();
    expect(fresh.rolls.where((r) => r.isActive).map((r) => r.id), [y.id]);
    expect(
      fresh.rolls.firstWhere((r) => r.id == x.id).status,
      RollStatus.finished,
    );
  });
}

class _SlowLocation extends FakeLocation {
  _SlowLocation(this._f);
  final Future<GeoFix?> _f;
  @override
  Future<GeoFix?> current() => _f;
}

/// Holds the next [readings] call until [hold] completes.
class _GatedRepository extends MemoryRollRepository {
  Completer<void>? hold;
  final entered = Completer<void>();

  @override
  Future<List<SavedReading>> readings() async {
    final h = hold;
    if (h != null && !entered.isCompleted) {
      entered.complete();
      await h.future;
    }
    return super.readings();
  }
}
