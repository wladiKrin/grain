import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/gear/library.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/main.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/roll_repository.dart';
import 'package:grain/rolls/snapshot_store.dart';
import 'package:grain/settings/settings.dart';

import 'support/gear_fixtures.dart';

void main() {
  test(
    'startup loads gear and rolls side by side, rolls loaded before it returns',
    () async {
      final tmp = Directory.systemTemp.createTempSync('grain-startup');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final settings = Completer<Settings>();
      final library = Completer<GearLibrary>();
      final snapshots = Completer<SnapshotStore>();
      final alongside = Completer<void>();
      final repo = MemoryRollRepository();
      final t = DateTime.utc(2026, 11, 1);
      await repo.saveRoll(
        Roll(
          id: 'r',
          number: 1,
          filmStock: 'HP5',
          filmType: FilmType.bwNeg,
          boxIso: 400,
          pushThirds: 0,
          format: FilmFormat.f135,
          size: 36,
          startFrame: StartFrame.one,
          status: RollStatus.active,
          startedAt: t,
          updatedAt: t,
        ),
      );
      final events = <String>[];
      var done = false;
      final parts =
          loadStartup(
            settings: settings.future,
            library: library.future,
            snapshots: snapshots.future,
            alongside: alongside.future,
            makeGear: (lib) {
              events.add('gear');
              return GearController.inMemory(library: lib);
            },
            makeRolls: (s, store) {
              events.add('rolls');
              return RollController(
                repository: repo,
                snapshots: store,
                settings: s,
              );
            },
          ).then((p) {
            done = true;
            return p;
          });

      // The gear does not wait for the snapshot directory or the settings.
      library.complete(fixtureLibrary());
      await pumpEventQueue();
      expect(events, ['gear']);

      settings.complete(Settings.inMemory());
      await pumpEventQueue();
      expect(events, ['gear']);
      snapshots.complete(SnapshotStore(tmp));
      await pumpEventQueue();
      expect(events, ['gear', 'rolls']);
      expect(done, isFalse); // still waiting on the orientation lock
      alongside.complete();
      final p = await parts;
      expect(p.rolls.active?.id, 'r');
      expect(p.gear.bodies, isNotEmpty);
    },
  );
}
