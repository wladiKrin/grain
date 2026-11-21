import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/gear/gear_repository.dart';
import 'package:grain/gear/gear_scales.dart';
import 'package:grain/gear/model.dart';

import '../support/gear_fixtures.dart';

void main() {
  late MemoryGearRepository repo;
  late GearController c;
  late int notified;
  final a1 = libBody('canon-a1');
  final fd28 = libLens('canon-fd-28-2.8');
  final fd50 = libLens('canon-fd-50-1.8');
  final zoom = libLens('canon-fd-35-70-3.5-4.5');

  GearController make() =>
      GearController(library: fixtureLibrary(), repository: repo);

  setUp(() async {
    repo = MemoryGearRepository();
    c = make();
    await c.load();
    notified = 0;
    c.addListener(() => notified++);
  });

  test('starts in No camera', () {
    expect(c.body, isNull);
    expect(c.lens, isNull);
    expect(c.focal, 50);
    expect(c.setup, const GearSetup());
  });

  test('inMemory works without load', () async {
    final m = GearController.inMemory();
    expect(m.bodies, isEmpty);
    expect(m.mounts, isEmpty);
    expect(m.setup, const GearSetup());
  });

  test('choosing a body picks its first favorite lens', () async {
    await c.toggleFavorite(fd50);
    await c.toggleFavorite(fd28);
    await c.selectBody(a1);
    expect(c.lens, fd28);
    expect(c.focal, 28);
  });

  test('a fixed-lens camera gets its only lens', () async {
    await c.selectBody(libBody('yashica-mat-124g'));
    expect(c.lens?.id, 'yashinon-80-3.5');
    expect(c.focal, 80);
  });

  test('keeps the current lens when it fits the new body', () async {
    await c.selectBody(a1);
    await c.selectLens(fd50);
    await c.selectBody(libBody('canon-ae1'));
    expect(c.lens, fd50);
  });

  test('lens chip cycles favorites and wraps', () async {
    await c.toggleFavorite(fd28);
    await c.toggleFavorite(fd50);
    await c.selectBody(a1);
    expect(c.lens, fd28);
    expect(await c.cycleLens(), isTrue);
    expect(c.lens, fd50);
    expect(await c.cycleLens(), isTrue);
    expect(c.lens, fd28);
  });

  test('cycling from a non-favorite lens goes to the first favorite', () async {
    await c.toggleFavorite(fd28);
    await c.selectBody(a1);
    await c.selectLens(fd50);
    expect(await c.cycleLens(), isTrue);
    expect(c.lens, fd28);
  });

  test('cycling without favorites changes nothing', () async {
    await c.selectBody(a1);
    final lensBefore = c.lens;
    var n = 0;
    c.addListener(() => n++);
    expect(await c.cycleLens(), isFalse);
    expect(c.lens, lensBefore);
    expect(n, 0);
  });

  test('selectLens rejects a lens from another mount', () async {
    await c.selectBody(a1);
    expect(() => c.selectLens(libLens('yashinon-80-3.5')), throwsArgumentError);
  });

  test('zoom keeps the focal length inside its range', () async {
    await c.selectBody(a1);
    await c.setFocal(100);
    expect(c.focal, 100);
    await c.selectLens(zoom);
    expect(c.focal, 70);
    await c.setFocal(20);
    expect(c.focal, 35);
  });

  test(
    'setFocal with an equal value does not notify; prime ignores it',
    () async {
      await c.selectBody(a1);
      await c.selectLens(zoom);
      await c.setFocal(50);
      final n = notified;
      await c.setFocal(50);
      expect(notified, n);
      await c.selectLens(fd50);
      final m = notified;
      await c.setFocal(100);
      expect(c.focal, 50);
      expect(notified, m);
    },
  );

  test('setFocal persists debounced, not per detent', () async {
    await c.selectBody(a1);
    await c.selectLens(zoom);
    for (final f in [40.0, 45.0, 50.0, 60.0]) {
      await c.setFocal(f);
    }
    expect((await repo.selection()).focal, isNot(60));
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect((await repo.selection()).focal, 60);
  });

  test('selection survives a restart', () async {
    await c.selectBody(a1);
    await c.selectLens(fd50);
    final c2 = make();
    await c2.load();
    expect(c2.body, a1);
    expect(c2.lens, fd50);
    expect(c2.focal, 50);
  });

  test('stale ids from storage fall back safely', () async {
    await repo.saveSelection(
      const StoredSelection(bodyId: 'gone', lensId: 'gone', focal: 35),
    );
    final c2 = make();
    await c2.load();
    expect(c2.body, isNull);
    expect(c2.lens, isNull);
    expect(c2.focal, 35);

    await repo.saveSelection(
      const StoredSelection(bodyId: 'canon-a1', lensId: 'gone'),
    );
    final c3 = make();
    await c3.load();
    expect(c3.body, a1);
    expect(c3.lens, isNull); // no favorites, several FD lenses
    await c3.toggleFavorite(fd28);
    final c4 = make();
    await c4.load();
    expect(c4.lens, fd28);
    expect(c4.focal, 28);
  });

  test('deleting the selected user body returns to No camera', () async {
    final mine = await c.saveUser(c.duplicateBody(a1));
    await c.selectBody(mine);
    expect(c.body, mine);
    await c.deleteUser(mine);
    expect(c.body, isNull);
    expect(c.lens, isNull);
    expect(c.bodies.any((b) => b.id == mine.id), isFalse);
    expect((await repo.selection()).bodyId, isNull);
  });

  test('deleting a selected user lens clears the lens', () async {
    final mine = await c.saveUser(c.duplicateLens(fd50));
    await c.selectBody(a1);
    await c.selectLens(mine);
    await c.deleteUser(mine);
    expect(c.body, a1);
    expect(c.lens, isNull);
    // deleting a bundled profile is a no-op
    await c.deleteUser(fd50);
    expect(c.lensesFor('canon-fd').contains(fd50), isTrue);
  });

  test('importing a bundled profile reuses it and stars it', () async {
    final n = c.bodies.length;
    final r = await c.importDoc(a1);
    expect(c.bodies.length, n);
    expect(c.isFavorite(a1), isTrue);
    expect(r.bodies.single.id, 'canon-a1');
    expect(r.summary, a1.displayName);
  });

  test('same id, different content → suffixed copy, once', () async {
    final n = c.bodies.length;
    final mine = a1.copyWith(model: 'A-1 mine');
    final r = await c.importDoc(mine);
    expect(r.bodies.single.id, 'canon-a1-2');
    expect(c.bodies.length, n + 1);
    expect(c.isUser(r.bodies.single), isTrue);
    final r2 = await c.importDoc(mine);
    expect(r2.bodies.single.id, 'canon-a1-2');
    expect(c.bodies.length, n + 1);
    final r3 = await c.importDoc(a1.copyWith(model: 'A-1 other'));
    expect(r3.bodies.single.id, 'canon-a1-3');
  });

  test('import with the id of an existing user profile keeps both', () async {
    final mine = await c.saveUser(c.duplicateBody(a1));
    final incoming = mine.copyWith(model: 'Different');
    final r = await c.importDoc(incoming);
    expect(r.bodies.single.id, '${mine.id}-2');
    expect(c.bodies.firstWhere((b) => b.id == mine.id), mine);
    expect((await repo.userBodies()).length, 2);
  });

  test('import notifies once', () async {
    await c.importDoc(a1.copyWith(model: 'A-1 mine'));
    expect(notified, 1);
  });

  test(
    'importing a kit stores body and lenses as starred user profiles',
    () async {
      final body = a1.copyWith(id: 'my-body', model: 'Kit body');
      final l1 = fd50.copyWith(id: 'my-lens-1', name: 'Kit 50');
      final l2 = fd28.copyWith(id: 'my-lens-2', name: 'Kit 28');
      final r = await c.importDoc(Kit(body, [l1, l2]));
      expect(r.bodies.single.id, 'my-body');
      expect([for (final l in r.lenses) l.id], ['my-lens-1', 'my-lens-2']);
      expect(r.summary, 'Canon Kit body, Kit 50, Kit 28');
      for (final p in [...r.bodies, ...r.lenses]) {
        expect(c.isUser(p), isTrue);
        expect(c.isFavorite(p), isTrue);
      }
      expect(c.favoriteBodies.single.id, 'my-body');
      expect(c.favoriteLensesFor('canon-fd').map((l) => l.name), [
        'Kit 28',
        'Kit 50',
      ]);
      expect((await repo.userLenses()).length, 2);
    },
  );

  test('duplicate and edit never changes the bundled profile', () async {
    final copy = await c.saveUser(c.duplicateBody(a1).copyWith(isoMax: 3200));
    expect(copy.id, 'canon-a-1-copy');
    expect(copy.model, 'A-1 (copy)');
    expect(copy.isoMax, 3200);
    expect(c.isUser(copy), isTrue);
    expect(fixtureLibrary().body('canon-a1'), a1);
    expect(c.bodies.firstWhere((b) => b.id == 'canon-a1'), a1);
    // a second duplicate gets a fresh id
    expect(c.duplicateBody(a1).id, 'canon-a-1-copy-2');
  });

  test(
    'saveUser of a new id that collides with a bundled one gets a suffix',
    () async {
      final s = await c.saveUser(a1.copyWith(model: 'Other'));
      expect(s.id, 'canon-a1-2');
      // updating an existing user profile keeps its id
      final u = await c.saveUser(s.copyWith(model: 'Other 2'));
      expect(u.id, 'canon-a1-2');
      expect((await repo.userBodies()).length, 1);
    },
  );

  test('editing the selected user body refreshes the selection', () async {
    final mine = await c.saveUser(c.duplicateBody(a1));
    await c.selectBody(mine);
    final edited = await c.saveUser(mine.copyWith(isoMax: 800));
    expect(c.body, edited);
  });

  test('lists are sorted and mounts known', () async {
    final names = c.lensesFor('canon-fd').map((l) => l.focalMin).toList();
    expect(names, [...names]..sort());
    final bs = c.bodies;
    expect(
      bs.map((b) => '${b.make} ${b.model}').toList(),
      [...bs.map((b) => '${b.make} ${b.model}')]..sort(),
    );
    expect(c.mounts, contains('canon-fd'));
    expect(c.mounts, [...c.mounts]..sort());
  });
}
