import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/backup/backup.dart';
import 'package:grain/exposure/mode.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/gear/gear_repository.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/rolls/codec.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/snapshot_store.dart';
import 'package:grain/settings/settings.dart';

import '../support/gear_fixtures.dart';

Directory tempDir(String name) {
  final d = Directory.systemTemp.createTempSync(name);
  addTearDown(() {
    if (d.existsSync()) d.deleteSync(recursive: true);
  });
  return d;
}

/// One phone: gear, rolls and settings, snapshots in a temp dir. Snapshots
/// taken while logging are written as [snapshotBytes].
class Phone {
  Phone({List<int> snapshotBytes = const [1, 2, 3]})
    : store = SnapshotStore(tempDir('grain-snaps')) {
    rolls = RollController.inMemory(
      settings: settings,
      snapshots: store,
      now: () => clock,
      takeSnapshot: (id) async {
        final f = store.file('$id.jpg')..writeAsBytesSync(snapshotBytes);
        return f.path;
      },
    );
  }

  /// The phone's clock; tests move it on.
  DateTime clock = DateTime.utc(2026, 11, 1, 10);
  final settings = Settings.inMemory();
  final gear = GearController(
    library: fixtureLibrary(),
    repository: MemoryGearRepository(),
  );
  final SnapshotStore store;
  late final RollController rolls;
}

Body myBody({String model = 'A-1 (mine)'}) =>
    libBody('canon-a1').copyWith(id: 'my-a1', model: model);
Lens myLens({String name = 'FD 50mm f/1.8 (mine)'}) =>
    libLens('canon-fd-50-1.8').copyWith(id: 'my-50', name: name);

const exposure = Exposure(
  mode: MeterMode.aperturePriority,
  aperture: 8,
  shutter: '1/125',
  exposureTime: 1 / 125,
  iso: 400,
  lensId: 'my-50',
  lensMake: 'Canon',
  lensName: 'FD 50mm f/1.8 (mine)',
  focal: 50,
  meteredEv: 12.3,
  offset: 0,
);

/// Snapshots attach after the write returns.
Future<void> settleSnapshots(RollController rolls) async {
  for (var i = 0; i < 100; i++) {
    final all = await rolls.allFrames();
    final done =
        all.every((r) => r.$2.every((f) => f.snapshot != null)) &&
        rolls.readings.every((r) => r.snapshot != null);
    if (done) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('snapshots never attached');
}

Future<Phone> filledPhone() async {
  final p = Phone();
  final body = await p.gear.saveUser(myBody());
  await p.gear.saveUser(myLens());
  await p.gear.toggleFavorite(body);
  await p.gear.toggleFavorite(libLens('canon-fd-28-2.8'));
  await p.rolls.startRoll(
    filmStock: 'Kodak Portra 400',
    filmType: FilmType.colorNeg,
    boxIso: 400,
    pushThirds: 0,
    body: body,
    size: 36,
    startFrame: StartFrame.one,
    notes: 'first',
  );
  await p.rolls.logFrame(exposure, note: 'tree');
  await p.rolls.logFrame(exposure);
  await p.rolls.startRoll(
    filmStock: 'Ilford HP5 Plus',
    filmType: FilmType.bwNeg,
    boxIso: 400,
    pushThirds: 3,
    body: body,
    size: 24,
    startFrame: StartFrame.zero,
  );
  await p.rolls.logFrame(exposure);
  await p.rolls.saveReading(
    exposure,
    body: body,
    format: FilmFormat.f135,
    note: 'window',
  );
  await settleSnapshots(p.rolls);
  return p;
}

Future<BackupContents> exportFrom(Phone p) async {
  final file = await writeBackup(
    out: tempDir('grain-out'),
    gear: p.gear,
    rolls: p.rolls,
    settings: p.settings,
    now: DateTime(2026, 11, 21, 14, 3),
  );
  expect(file.uri.pathSegments.last, 'grain-backup-2026-11-21.zip');
  return readBackup(file.path);
}

Future<ImportReport> importInto(
  Phone p,
  BackupContents c, {
  bool applySettings = false,
}) => importBackup(
  c,
  gear: p.gear,
  rolls: p.rolls,
  settings: p.settings,
  applySettings: applySettings,
);

/// A zip with [entries] (name → bytes).
String zipOf(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final e in entries.entries) {
    archive.addFile(ArchiveFile.bytes(e.key, e.value));
  }
  final f = File('${tempDir('grain-zip').path}/x.zip')
    ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
  return f.path;
}

List<int> jsonBytes(Object json) => utf8.encode(jsonEncode(json));

Matcher refusedWith(String message) => throwsA(
  isA<BackupFormatException>().having((e) => e.message, 'message', message),
);

void main() {
  test('export → import on an empty phone restores everything', () async {
    final a = await filledPhone();
    final c = await exportFrom(a);
    expect(c.rolls, hasLength(2));
    expect(c.readings, hasLength(1));
    expect(c.snapshotNames, hasLength(4));

    final b = Phone();
    final report = await importInto(b, c);
    expect(report.rollsAdded, 2);
    expect(report.readingsAdded, 1);
    expect(report.profilesAdded, 2);
    expect(report.snapshotsAdded, 4);
    expect(report.rollsDeactivated, 0);
    expect(report.summary, 'Added 2 rolls, 1 saved reading, 2 profiles.');

    final rollsA = await a.rolls.allFrames();
    final rollsB = await b.rolls.allFrames();
    int byNumber((Roll, List<Frame>) x, (Roll, List<Frame>) y) =>
        x.$1.number.compareTo(y.$1.number);
    rollsA.sort(byNumber);
    rollsB.sort(byNumber);
    expect(rollsB.map((r) => r.$1), rollsA.map((r) => r.$1));
    for (var i = 0; i < rollsA.length; i++) {
      expect(rollsB[i].$2, rollsA[i].$2);
    }
    expect(b.rolls.active?.id, a.rolls.active?.id);
    expect(b.rolls.readings, a.rolls.readings);
    expect(b.gear.userProfiles, unorderedEquals(a.gear.userProfiles));
    expect(b.gear.favoriteIds(ProfileKind.body), {'my-a1'});
    expect(b.gear.favoriteIds(ProfileKind.lens), {'canon-fd-28-2.8'});
    for (final r in rollsA) {
      for (final f in r.$2) {
        expect(
          b.store.file(f.snapshot!).readAsBytesSync(),
          a.store.file(f.snapshot!).readAsBytesSync(),
        );
      }
    }
    expect(
      b.store.file(b.rolls.readings.single.snapshot!).existsSync(),
      isTrue,
    );
  });

  test('importing the same backup twice adds nothing', () async {
    final a = await filledPhone();
    final c = await exportFrom(a);
    final b = Phone();
    await importInto(b, c);
    final again = await importInto(b, c);
    expect(again.rollsAdded + again.readingsAdded + again.profilesAdded, 0);
    expect(again.rollsCopied + again.readingsCopied + again.profilesCopied, 0);
    expect(again.rollsSkipped, 2);
    expect(again.readingsSkipped, 1);
    expect(again.profilesSkipped, 2);
    expect(again.snapshotsAdded, 0);
    expect(
      again.summary,
      startsWith('Added 0 rolls, 0 saved readings, 0 profiles.'),
    );
    expect(again.summary, endsWith('Skipped 5 already on this phone.'));
    expect(b.rolls.rolls, hasLength(2));
    // Back onto the original phone: everything is already there.
    final home = await importInto(a, c);
    expect(home.rollsSkipped, 2);
    expect(home.rollsAdded + home.rollsCopied, 0);
  });

  test(
    'an active roll stays the only active one, and re-imports as identical',
    () async {
      final a = await filledPhone();
      final c = await exportFrom(a);
      final b = Phone();
      await b.rolls.startRoll(
        filmStock: 'Fomapan 100',
        filmType: FilmType.bwNeg,
        boxIso: 100,
        pushThirds: 0,
        body: null,
        size: 36,
        startFrame: StartFrame.one,
      );
      await b.rolls.logFrame(exposure, note: 'here');
      await settleSnapshots(b.rolls);
      final mine = b.rolls.active!.id;
      final framesHere = b.rolls.activeFrames;
      final report = await importInto(b, c);
      expect(b.rolls.activeFrames, framesHere);
      expect(
        (await b.rolls.allFrames()).firstWhere((r) => r.$1.id == mine).$2,
        framesHere,
      );
      expect(report.rollsDeactivated, 1);
      expect(
        report.summary,
        endsWith('1 imported active roll is now finished.'),
      );
      expect(b.rolls.rolls.where((r) => r.isActive).single.id, mine);
      // B's backup brought back to A: the finished copy is the same roll.
      final fromB = await exportFrom(b);
      final back = await importInto(a, fromB);
      expect(back.rollsAdded, 1); // Fomapan
      expect(back.rollsDeactivated, 1);
      expect(back.rollsSkipped, 2);
      expect(back.rollsCopied, 0);
      expect(a.rolls.rolls.where((r) => r.isActive), hasLength(1));
    },
  );

  test(
    'settings are applied only when asked; calibration never travels',
    () async {
      final a = await filledPhone();
      await a.settings.setHaptics(false);
      await a.settings.setViewfinderOn(false);
      await a.settings.setSnapshots(false);
      await a.settings.setCalibrationThirds(4);
      await a.settings.setLocation(true);
      await a.settings.setHistogram(true);
      expect(a.settings.backupMap(), {
        'haptics': false,
        'viewfinderOn': false,
        'snapshots': false,
        'histogram': true,
        'shakeWarning': false,
        'clickSound': false,
      });
      final c = await exportFrom(a);

      final b = Phone();
      await importInto(b, c);
      expect(b.settings.haptics, isTrue);
      expect(b.settings.viewfinderOn, isTrue);
      expect(b.settings.snapshots, isTrue);
      expect(b.settings.histogram, isFalse);

      final d = Phone();
      await importInto(d, c, applySettings: true);
      expect(d.settings.haptics, isFalse);
      expect(d.settings.viewfinderOn, isFalse);
      expect(d.settings.snapshots, isFalse);
      expect(d.settings.histogram, isTrue);
      expect(d.settings.calibrationThirds, 0);
      expect(d.settings.location, isFalse);

      final e = Settings.inMemory();
      await e.applyBackupMap({
        'haptics': 'no',
        'viewfinderOn': 0,
        'snapshots': false,
        'calibrationThirds': 3,
        'location': true,
      });
      expect(e.haptics, isTrue);
      expect(e.viewfinderOn, isTrue);
      expect(e.snapshots, isFalse);
      expect(e.calibrationThirds, 0);
      expect(e.location, isFalse);
    },
  );

  test('not a backup and newer schema are refused', () async {
    final notZip = File('${tempDir('grain-nz').path}/x.zip')
      ..writeAsStringSync('hello');
    await expectLater(
      readBackup(notZip.path),
      refusedWith('Not a Grain backup'),
    );
    await expectLater(
      readBackup(
        zipOf({
          'photo.jpg': [1, 2, 3],
        }),
      ),
      refusedWith('Not a Grain backup'),
    );
    await expectLater(
      readBackup(zipOf({'grain-backup.json': utf8.encode('{nope')})),
      refusedWith('Not a Grain backup'),
    );
    await expectLater(
      readBackup(
        zipOf({
          'grain-backup.json': jsonBytes({'schema': 1, 'type': 'grain-roll'}),
        }),
      ),
      refusedWith('Not a Grain backup'),
    );
    await expectLater(
      readBackup(
        zipOf({
          'grain-backup.json': jsonBytes({'schema': 2, 'type': 'grain-backup'}),
        }),
      ),
      refusedWith('Made by a newer version of Grain (schema 2)'),
    );
  });

  test(
    'a damaged or unsafe backup is refused before anything changes',
    () async {
      final good = jsonBytes({
        'schema': 1,
        'type': 'grain-backup',
        'rolls': <Object>[],
      });
      await expectLater(
        readBackup(
          zipOf({
            'grain-backup.json': good,
            '../evil.jpg': [1],
          }),
        ),
        refusedWith('The backup contains an unsafe file name: ../evil.jpg'),
      );
      await expectLater(
        readBackup(
          zipOf({
            'grain-backup.json': good,
            'snapshots/../../x.jpg': [1],
          }),
        ),
        throwsA(isA<BackupFormatException>()),
      );
      await expectLater(
        readBackup(
          zipOf({
            'grain-backup.json': good,
            '/etc/x.jpg': [1],
          }),
        ),
        throwsA(isA<BackupFormatException>()),
      );
      await expectLater(
        readBackup(
          zipOf({
            'grain-backup.json': jsonBytes({
              'schema': 1,
              'type': 'grain-backup',
              'rolls': [
                {'schema': 1, 'type': 'grain-roll', 'roll': 3},
              ],
            }),
          }),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            startsWith('The backup is damaged: rolls[0]'),
          ),
        ),
      );
      // A snapshot reference that is not a plain snapshot name.
      final a = await filledPhone();
      final c = await exportFrom(a);
      final (r, frames) = c.rolls.first;
      final json = {
        'schema': 1,
        'type': 'grain-backup',
        'rolls': [
          rollToJson(r, [
            frames.first.copyWith(snapshot: () => '../../databases/grain.db'),
          ]),
        ],
      };
      await expectLater(
        readBackup(zipOf({'grain-backup.json': jsonBytes(json)})),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('not a snapshot name'),
          ),
        ),
      );
    },
  );

  test('missing snapshot files are skipped on export', () async {
    final a = await filledPhone();
    final all = await a.rolls.allFrames();
    final gone = all.first.$2.first.snapshot!;
    a.store.file(gone).deleteSync();
    final file = await writeBackup(
      out: tempDir('grain-out'),
      gear: a.gear,
      rolls: a.rolls,
      settings: a.settings,
      now: DateTime(2026, 11, 21),
    );
    final zip = ZipDecoder().decodeStream(InputFileStream(file.path));
    final names = zip.files.map((f) => f.name).toList();
    expect(names, contains('grain-backup.json'));
    expect(names, isNot(contains('snapshots/$gone')));
    expect(names.where((n) => n.startsWith('snapshots/')), hasLength(3));
    final c = await readBackup(file.path);
    expect(await c.snapshot(gone), isNull);
    expect(await c.snapshot(c.snapshotNames.first), [1, 2, 3]);
    final top = jsonDecode(
      utf8.decode(zip.findFile('grain-backup.json')!.content),
    ) as Map<String, Object?>;
    expect(top['schema'], 1);
    expect(top['type'], 'grain-backup');
    expect(top['app'], '1.0.0');
    expect(top['exportedAt'], startsWith('2026-11-21T00:00:00'));
    expect(top['favorites'], {
      'body': ['my-a1'],
      'lens': ['canon-fd-28-2.8'],
    });
    expect(
      (top['profiles'] as List).map((p) => (p as Map)['id']),
      unorderedEquals(['my-a1', 'my-50']),
    );
    expect(top['settings'], {
      'haptics': true,
      'viewfinderOn': true,
      'snapshots': true,
      'histogram': false,
      'shakeWarning': false,
      'clickSound': false,
    });
  });

  test('a snapshot here with other bytes is not overwritten', () async {
    final a = await filledPhone();
    final c = await exportFrom(a);
    final b = Phone();
    final name = c.rolls.first.$2.first.snapshot!;
    b.store.file(name).writeAsBytesSync([9, 9]);
    await importInto(b, c);
    expect(b.store.file(name).readAsBytesSync(), [9, 9]);
    final all = await b.rolls.allFrames();
    final f = all
        .expand((r) => r.$2)
        .firstWhere((f) => f.id == c.rolls.first.$2.first.id);
    expect(f.snapshot, isNot(name));
    expect(b.store.file(f.snapshot!).readAsBytesSync(), [1, 2, 3]);
    // The renamed snapshot does not make the roll differ next time.
    final again = await importInto(b, c);
    expect(again.rollsSkipped, 2);
    expect(again.rollsAdded + again.rollsCopied, 0);
    expect(again.snapshotsAdded, 0);
  });

  test(
    'a roll finished here since the backup re-imports as the same roll',
    () async {
      final a = await filledPhone();
      final c = await exportFrom(a);
      final hp5 = a.rolls.active!;
      a.clock = a.clock.add(const Duration(days: 2));
      await a.rolls.finishRoll(hp5.id);
      final finished = a.rolls.rolls.firstWhere((r) => r.id == hp5.id);
      expect(finished.updatedAt, isNot(hp5.updatedAt));
      final report = await importInto(a, c);
      expect(report.rollsSkipped, 2);
      expect(report.rollsCopied + report.rollsAdded, 0);
      expect(a.rolls.rolls, hasLength(2));
      // Also when the next roll was started (which finishes the old one).
      final b = Phone();
      await importInto(b, c);
      b.clock = b.clock.add(const Duration(days: 3));
      await b.rolls.startRoll(
        filmStock: 'Fomapan 100',
        filmType: FilmType.bwNeg,
        boxIso: 100,
        pushThirds: 0,
        body: null,
        size: 36,
        startFrame: StartFrame.one,
      );
      final again = await importInto(b, c);
      expect(again.rollsSkipped, 2);
      expect(again.rollsCopied + again.rollsAdded, 0);
      expect(again.rollsDeactivated, 0);
      expect(b.rolls.rolls, hasLength(3));
    },
  );

  test('an edited backup imported twice is kept as a copy only once', () async {
    final a = await filledPhone();
    final b = Phone();
    await importInto(b, await exportFrom(a));
    final roll = a.rolls.rolls.last;
    a.clock = a.clock.add(const Duration(hours: 1));
    await a.rolls.updateRoll(roll.copyWith(notes: 'developed in Rodinal'));
    await a.rolls.updateReading(
      a.rolls.readings.single.copyWith(note: () => 'by the window'),
    );
    final edited = await exportFrom(a);
    final first = await importInto(b, edited);
    expect(first.rollsCopied, 1);
    expect(first.readingsCopied, 1);
    expect(first.snapshotsAdded, 3); // the copies get their own files
    final second = await importInto(b, edited);
    expect(second.rollsCopied + second.readingsCopied, 0);
    expect(second.rollsAdded + second.readingsAdded, 0);
    expect(second.rollsSkipped, 2);
    expect(second.readingsSkipped, 1);
    expect(second.snapshotsAdded, 0);
    expect(b.rolls.rolls, hasLength(3));
    expect(b.rolls.readings, hasLength(2));
  });

  test(
    'snapshot files missing here are restored for records already here',
    () async {
      final a = await filledPhone();
      final c = await exportFrom(a);
      final b = Phone();
      await importInto(b, c);
      // A system restore brings the database back without snapshots/.
      for (final f in b.store.dir.listSync()) {
        f.deleteSync();
      }
      final report = await importInto(b, c);
      expect(report.rollsSkipped, 2);
      expect(report.readingsSkipped, 1);
      expect(report.rollsAdded + report.rollsCopied, 0);
      expect(report.snapshotsAdded, 4);
      for (final (_, frames) in await b.rolls.allFrames()) {
        for (final f in frames) {
          expect(b.store.file(f.snapshot!).readAsBytesSync(), [1, 2, 3]);
        }
      }
      expect(
        b.store.file(b.rolls.readings.single.snapshot!).readAsBytesSync(),
        [1, 2, 3],
      );
      expect(
        b.store.dir.listSync().where((f) => f.path.endsWith('.part')),
        isEmpty,
      );
    },
  );

  test(
    'an active roll started after planning is finished at write time',
    () async {
      final p = Phone();
      await p.rolls.startRoll(
        filmStock: 'Fomapan 100',
        filmType: FilmType.bwNeg,
        boxIso: 100,
        pushThirds: 0,
        body: null,
        size: 36,
        startFrame: StartFrame.one,
      );
      final t = DateTime.utc(2026, 10, 1, 12);
      final incoming = Roll(
        id: 'other',
        number: 7,
        filmStock: 'Kodak Gold 200',
        filmType: FilmType.colorNeg,
        boxIso: 200,
        pushThirds: 0,
        format: FilmFormat.f135,
        size: 36,
        startFrame: StartFrame.one,
        status: RollStatus.active,
        startedAt: t,
        updatedAt: t,
      );
      // Position order is not time order (a frame inserted later).
      final frames = [
        Frame(
          id: 'x1',
          rollId: 'other',
          position: 0,
          number: 1,
          takenAt: t.add(const Duration(hours: 5)),
          updatedAt: t,
        ),
        Frame(
          id: 'x2',
          rollId: 'other',
          position: 1,
          number: 2,
          takenAt: t.add(const Duration(hours: 1)),
          updatedAt: t,
        ),
      ];
      final finished = await p.rolls.importRecords(
        MergePlan(
          rolls: [(incoming, frames)],
          readings: const [],
          snapshots: const {},
          report: const ImportReport(rollsAdded: 1),
        ),
      );
      expect(finished, 1);
      final stored = p.rolls.rolls.firstWhere((r) => r.id == 'other');
      expect(stored.status, RollStatus.finished);
      expect(stored.finishedAt, t.add(const Duration(hours: 5)));
      expect(p.rolls.rolls.where((r) => r.isActive), hasLength(1));
    },
  );

  test('gear mergeProfiles: identical skipped, different suffixed, favorites unioned', () async {
    final g = GearController(
      library: fixtureLibrary(),
      repository: MemoryGearRepository(),
    );
    await g.saveUser(myBody());
    await g.saveUser(myLens());
    await g.toggleFavorite(libLens('canon-fd-50-1.8'));
    final changed = myLens(name: 'FD 50mm f/1.8 (other)');
    final fresh = myBody(model: 'AE-1').copyWith(id: 'my-ae1');
    final r = await g.mergeProfiles(
      [myBody(), changed, fresh, libBody('canon-a1')],
      {
        ProfileKind.body: {'my-ae1'},
        ProfileKind.lens: {'my-50'},
      },
    );
    expect(r.skipped, 2);
    expect(r.copied, 1);
    expect(r.added, 1);
    expect(r.renames, {'lens:my-50': 'my-50-2'});
    expect(
      g.userProfiles.firstWhere((p) => p.id == 'my-50-2'),
      changed.copyWith(id: 'my-50-2'),
    );
    expect(g.userProfiles.firstWhere((p) => p.id == 'my-50'), myLens());
    expect(g.favoriteIds(ProfileKind.body), {'my-ae1'});
    expect(g.favoriteIds(ProfileKind.lens), {'canon-fd-50-1.8', 'my-50-2'});
    // The same file again: the copy is recognised, nothing new is stored.
    final again = await g.mergeProfiles([myBody(), changed, fresh], const {});
    expect(again.skipped, 3);
    expect(again.added + again.copied, 0);
    expect(again.renames, {'lens:my-50': 'my-50-2'});
    expect(g.userProfiles, hasLength(4));
  });
  group(
    'local actions that only bump updatedAt keep a re-import identical',
    () {
      Future<void> expectSkipped(Phone a, BackupContents c) async {
        final before = a.store.dir.listSync().map((f) => f.path).toSet();
        final report = await importInto(a, c);
        expect(report.rollsSkipped, 2);
        expect(report.readingsSkipped, 1);
        expect(report.rollsAdded + report.rollsCopied, 0);
        expect(report.readingsAdded + report.readingsCopied, 0);
        expect(report.snapshotsAdded, 0);
        expect(a.rolls.rolls, hasLength(2));
        expect(a.rolls.readings, hasLength(1));
        expect(a.store.dir.listSync().map((f) => f.path).toSet(), before);
      }

      test('deleteFrameSnapshot, then the older backup', () async {
        final a = await filledPhone();
        final c = await exportFrom(a);
        a.clock = a.clock.add(const Duration(hours: 1));
        final f = a.rolls.activeFrames.first;
        await a.rolls.deleteFrameSnapshot(f.rollId, f.id);
        expect(a.rolls.activeFrames.first.updatedAt, isNot(f.updatedAt));
        await expectSkipped(a, c);
        expect(a.rolls.activeFrames.first.snapshot, isNull);
        final stored = (await a.rolls.allFrames())
            .firstWhere((r) => r.$1.id == f.rollId)
            .$2
            .first;
        expect(stored.snapshot, isNull);
      });

      test('updateFrame with no change, then the older backup', () async {
        final a = await filledPhone();
        final c = await exportFrom(a);
        a.clock = a.clock.add(const Duration(hours: 1));
        final f = a.rolls.activeFrames.first;
        await a.rolls.updateFrame(f);
        expect(a.rolls.activeFrames.first.updatedAt, isNot(f.updatedAt));
        await expectSkipped(a, c);
      });

      test('deleteReadingSnapshot, then the older backup', () async {
        final a = await filledPhone();
        final c = await exportFrom(a);
        a.clock = a.clock.add(const Duration(hours: 1));
        final r = a.rolls.readings.single;
        await a.rolls.deleteReadingSnapshot(r.id);
        expect(a.rolls.readings.single.updatedAt, isNot(r.updatedAt));
        await expectSkipped(a, c);
        expect(a.rolls.readings.single.snapshot, isNull);
      });

      test('updateReading with no change, then the older backup', () async {
        final a = await filledPhone();
        final c = await exportFrom(a);
        a.clock = a.clock.add(const Duration(hours: 1));
        final r = a.rolls.readings.single;
        await a.rolls.updateReading(r);
        expect(a.rolls.readings.single.updatedAt, isNot(r.updatedAt));
        await expectSkipped(a, c);
      });

      test(
        'updateRoll with no change on the active roll, then the older backup',
        () async {
          final a = await filledPhone();
          final c = await exportFrom(a);
          a.clock = a.clock.add(const Duration(hours: 1));
          await a.rolls.updateRoll(a.rolls.active!);
          await expectSkipped(a, c);
        },
      );
    },
  );

  test(
    'a backup without latitude keys imports and re-imports as identical',
    () async {
      final a = await filledPhone();
      final file = await writeBackup(
        out: tempDir('grain-out'),
        gear: a.gear,
        rolls: a.rolls,
        settings: a.settings,
        now: DateTime(2026, 11, 21),
      );
      final zip = ZipDecoder().decodeStream(InputFileStream(file.path));
      final top = jsonDecode(
        utf8.decode(zip.findFile('grain-backup.json')!.content),
      ) as Map<String, Object?>;
      for (final r in top['rolls'] as List) {
        final film = ((r as Map)['roll'] as Map)['film'] as Map;
        expect(film.containsKey('latitudeUnderHalves'), isTrue);
        film
          ..remove('latitudeUnderHalves')
          ..remove('latitudeOverHalves');
      }
      final entries = <String, List<int>>{
        for (final f in zip.files)
          if (f.isFile) f.name: f.content,
        'grain-backup.json': jsonBytes(top),
      };
      final c = await readBackup(zipOf(entries));
      final b = Phone();
      final first = await importInto(b, c);
      expect(first.rollsAdded, 2);
      expect(b.rolls.rolls.every((r) => r.latitudeUnderHalves == null), isTrue);
      expect(b.rolls.rolls.every((r) => r.latitudeOverHalves == null), isTrue);
      final again = await importInto(b, c);
      expect(again.rollsSkipped, 2);
      expect(again.rollsAdded + again.rollsCopied, 0);
    },
  );

  test('a roll differing only in latitude is imported as a copy', () async {
    final a = await filledPhone();
    final c = await exportFrom(a);
    final b = Phone();
    await importInto(b, c);
    final r = b.rolls.rolls.first;
    await b.rolls.updateRoll(r.copyWith(latitudeOverHalves: () => 4));
    final report = await importInto(b, c);
    expect(report.rollsCopied, 1);
    expect(report.rollsSkipped, 1);
  });
}
