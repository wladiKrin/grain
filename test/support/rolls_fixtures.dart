import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/rolls/location.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/snapshot_store.dart';
import 'package:grain/settings/settings.dart';

/// An in-memory [RollController] writing snapshots to a fresh temp dir,
/// removed when the test ends.
RollController inMemoryRolls({
  Settings? settings,
  TakeSnapshot? takeSnapshot,
  LocationSource? location,
  DateTime Function()? now,
}) {
  final dir = Directory.systemTemp.createTempSync('grain-test');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return RollController.inMemory(
    settings: settings ?? Settings.inMemory(),
    snapshots: SnapshotStore(dir),
    takeSnapshot: takeSnapshot,
    location: location,
    now: now,
  );
}
