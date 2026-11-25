import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/save.dart';
import 'package:grain/rolls/export.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/snapshot_store.dart';
import 'package:grain/rolls/ui/export_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_platform.dart';
import '../support/rolls_fixtures.dart';
import 'support.dart';

String base(File f) => f.uri.pathSegments.last;

({Directory out, SnapshotStore store}) dirs() {
  final root = Directory.systemTemp.createTempSync('grain-exp');
  addTearDown(() => root.deleteSync(recursive: true));
  final snaps = Directory('${root.path}/snaps')..createSync();
  return (out: Directory('${root.path}/out'), store: SnapshotStore(snaps));
}

Frame fr(int number, String? snapshot, {String id = ''}) => Frame(
  id: id.isEmpty ? 'f$number' : id,
  rollId: 'r',
  position: number,
  number: number,
  snapshot: snapshot,
  updatedAt: t0,
);

final r4 = roll(number: 4);

void main() {
  test('export writes csv, json and a zip of existing snapshots', () async {
    final d = dirs();
    d.store.file('a.jpg').writeAsBytesSync([1, 2, 3]);
    d.store.file('b.jpg').writeAsBytesSync([4, 5]);
    final files = await exportRoll(
      r4,
      [fr(1, 'a.jpg'), fr(2, 'b.jpg'), fr(3, 'missing.jpg'), fr(4, null)],
      out: d.out,
      store: d.store,
      withSnapshots: true,
    );
    expect(files.map(base), [
      'roll-4-ilford-hp5-plus.csv',
      'roll-4-ilford-hp5-plus.json',
      'roll-4-ilford-hp5-plus-snapshots.zip',
    ]);
    final zip = ZipDecoder().decodeBytes(files.last.readAsBytesSync());
    expect(zip.files.map((f) => f.name), ['frame-1.jpg', 'frame-2.jpg']);
    expect(zip.files.first.content, [1, 2, 3]);
    expect(files.first.readAsBytesSync().take(3), [0xEF, 0xBB, 0xBF]);
  });

  test('repeated labels get a suffix in the zip', () async {
    final d = dirs();
    d.store.file('a.jpg').writeAsBytesSync([1]);
    d.store.file('b.jpg').writeAsBytesSync([2]);
    final files = await exportRoll(
      r4,
      [fr(5, 'a.jpg', id: 'x'), fr(5, 'b.jpg', id: 'y')],
      out: d.out,
      store: d.store,
      withSnapshots: true,
    );
    final zip = ZipDecoder().decodeBytes(files.last.readAsBytesSync());
    expect(zip.files.map((f) => f.name), ['frame-5.jpg', 'frame-5-2.jpg']);
  });

  test(
    'with a zip, csv and json name each snapshot by its zip entry',
    () async {
      final d = dirs();
      d.store.file('a.jpg').writeAsBytesSync([1]);
      d.store.file('b.jpg').writeAsBytesSync([2]);
      final files = await exportRoll(
        r4,
        [
          fr(5, 'a.jpg', id: 'x'),
          fr(5, 'b.jpg', id: 'y'),
          fr(6, 'missing.jpg'),
          fr(7, null),
        ],
        out: d.out,
        store: d.store,
        withSnapshots: true,
      );
      final zip = ZipDecoder().decodeBytes(files.last.readAsBytesSync());
      final entries = zip.files.map((f) => f.name).toList();
      expect(entries, ['frame-5.jpg', 'frame-5-2.jpg']);
      final json =
          jsonDecode(files[1].readAsStringSync()) as Map<String, Object?>;
      final snaps = [
        for (final f in json['frames']! as List) (f as Map)['snapshot'],
      ];
      expect(snaps, ['frame-5.jpg', 'frame-5-2.jpg', null, null]);
      final csv = files.first.readAsStringSync().trim().split(RegExp(r'\r?\n'));
      expect(csv.skip(1).map((l) => l.split(',').last), [
        'frame-5.jpg',
        'frame-5-2.jpg',
        '',
        '',
      ]);
    },
  );

  test('a frame whose snapshot file is missing has a blank name when a zip is made', () async {
    final d = dirs();
    d.store.file('a.jpg').writeAsBytesSync([1]);
    final files = await exportRoll(
      r4,
      [fr(1, 'a.jpg'), fr(2, 'gone.jpg')],
      out: d.out,
      store: d.store,
      withSnapshots: true,
    );
    final csv = files.first.readAsStringSync().trim().split(RegExp(r'\r?\n'));
    expect(csv.skip(1).map((l) => l.split(',').last), ['frame-1.jpg', '']);
    final json =
        jsonDecode(files[1].readAsStringSync()) as Map<String, Object?>;
    final fs = json['frames']! as List;
    expect((fs[0] as Map)['snapshot'], 'frame-1.jpg');
    expect((fs[1] as Map)['snapshot'], isNull);
  });

  test('without a zip, csv and json keep the stored snapshot names', () async {
    final d = dirs();
    d.store.file('a.jpg').writeAsBytesSync([1]);
    final files = await exportRoll(
      r4,
      [fr(1, 'a.jpg')],
      out: d.out,
      store: d.store,
      withSnapshots: false,
    );
    expect(files, hasLength(2));
    final json =
        jsonDecode(files[1].readAsStringSync()) as Map<String, Object?>;
    expect(((json['frames']! as List).single as Map)['snapshot'], 'a.jpg');
    expect(files.first.readAsStringSync().trim().split(',').last, 'a.jpg');
  });

  test('no snapshots → no zip even when asked', () async {
    final d = dirs();
    final files = await exportRoll(
      r4,
      [fr(1, 'gone.jpg'), fr(2, null)],
      out: d.out,
      store: d.store,
      withSnapshots: true,
    );
    expect(files.map(base), [
      'roll-4-ilford-hp5-plus.csv',
      'roll-4-ilford-hp5-plus.json',
    ]);
  });

  testWidgets('export sheet shares the files', (tester) async {
    final rolls = inMemoryRolls();
    final started = await tester.runAsync(() async {
      final r = await rolls.startRoll(
        filmStock: 'Ilford HP5 Plus',
        filmType: FilmType.bwNeg,
        boxIso: 400,
        pushThirds: 0,
        body: null,
        size: 36,
        startFrame: StartFrame.one,
      );
      return r;
    });
    final platform = FakeGearPlatform();
    addTearDown(() {
      final d = platform.exportDir;
      if (d != null && d.existsSync()) d.deleteSync(recursive: true);
    });
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    unawaited(
      showExportSheet(
        ctx,
        roll: started!.copyWith(number: 4),
        rolls: rolls,
        platform: platform,
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Export roll 4'), findsOneWidget);
    expect(find.text('Include snapshots (zip)'), findsNothing);
    await tester.tap(find.text('Share'));
    for (var i = 0; i < 50 && platform.sharedPaths.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(platform.sharedPaths.single.map((p) => p.split('/').last), [
      'roll-4-ilford-hp5-plus.csv',
      'roll-4-ilford-hp5-plus.json',
    ]);
    expect(platform.sharedSubjects.single, 'Roll 4 · Ilford HP5 Plus');
    expect(platform.saves, isEmpty);
  });

  for (final (label, result, message, closes) in [
    ('saved', null, 'Saved roll-4-ilford-hp5-plus.zip', true),
    // The provider's name, not the one asked for.
    (
      'renamed',
      const Saved(['roll-4-ilford-hp5-plus (1).zip']),
      'Saved roll-4-ilford-hp5-plus (1).zip',
      true,
    ),
    ('failed', const SaveFailed('no space'), "Couldn't save: no space", false),
    ('cancelled', const SaveCancelled(), null, false),
  ]) {
    testWidgets('export sheet saves to the device: $label', (tester) async {
      final rolls = inMemoryRolls();
      final started = await tester.runAsync(
        () => rolls.startRoll(
          filmStock: 'Ilford HP5 Plus',
          filmType: FilmType.bwNeg,
          boxIso: 400,
          pushThirds: 0,
          body: null,
          size: 36,
          startFrame: StartFrame.one,
        ),
      );
      final platform = FakeGearPlatform()..saveResult = result;
      addTearDown(() {
        final d = platform.exportDir;
        if (d != null && d.existsSync()) d.deleteSync(recursive: true);
      });
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      unawaited(
        showExportSheet(
          ctx,
          roll: started!.copyWith(number: 4),
          rolls: rolls,
          platform: platform,
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Share'), findsOneWidget);
      expect(
        find.text(
          'Save to device puts the files in one zip, which can go anywhere, '
          'Downloads too.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Save to device'));
      for (var i = 0; i < 50 && platform.saves.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      // One zip, so it can be saved anywhere (Downloads too).
      expect(platform.saves.single, [
        ('roll-4-ilford-hp5-plus.zip', 'application/zip'),
      ]);
      final zip = ZipDecoder().decodeBytes(
        File('${platform.exportDir!.path}/roll-4-ilford-hp5-plus.zip')
            .readAsBytesSync(),
      );
      expect(zip.files.map((f) => f.name), [
        'roll-4-ilford-hp5-plus.csv',
        'roll-4-ilford-hp5-plus.json',
      ]);
      expect(platform.sharedPaths, isEmpty);
      expect(
        find.text('Export roll 4'),
        closes ? findsNothing : findsOneWidget,
      );
      if (message == null) {
        expect(find.byType(SnackBar), findsNothing);
      } else {
        expect(find.text(message), findsOneWidget);
      }
    });
  }

  test('bundleRoll puts every file of the export in one zip', () async {
    final d = dirs();
    d.store.file('a.jpg').writeAsBytesSync([1, 2, 3]);
    final files = await exportRoll(
      r4,
      [fr(1, 'a.jpg'), fr(2, null)],
      out: d.out,
      store: d.store,
      withSnapshots: true,
    );
    final bundle = await bundleRoll(r4, files, out: d.out);
    expect(base(bundle), 'roll-4-ilford-hp5-plus.zip');
    final zip = ZipDecoder().decodeBytes(bundle.readAsBytesSync());
    expect(zip.files.map((f) => f.name), [
      'roll-4-ilford-hp5-plus.csv',
      'roll-4-ilford-hp5-plus.json',
      'roll-4-ilford-hp5-plus-snapshots.zip',
    ]);
    for (final (i, f) in files.indexed) {
      expect(zip.files[i].content, f.readAsBytesSync());
    }
    // The snapshots zip is stored, not compressed again.
    expect(zip.files.last.compression, CompressionType.none);
    final inner = ZipDecoder().decodeBytes(zip.files.last.content);
    expect(inner.files.single.name, 'frame-1.jpg');
  });

  test('mimeOf and savedMessage', () {
    expect(mimeOf('a.jpg'), 'image/jpeg');
    expect(mimeOf('a.txt'), 'text/plain');
    expect(mimeOf('a.zip'), 'application/zip');
    expect(mimeOf('a.CSV'), 'text/csv');
    expect(mimeOf('a'), 'application/octet-stream');
    expect(savedMessage(['x.zip']), 'Saved x.zip');
    expect(savedMessage(['a', 'b', 'c']), 'Saved 3 files');
  });
}
