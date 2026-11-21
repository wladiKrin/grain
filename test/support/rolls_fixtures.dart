import 'dart:io';

import 'package:grain/rolls/location.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/snapshot_store.dart';
import 'package:grain/settings/settings.dart';

/// An in-memory [RollController] writing snapshots to a fresh temp dir.
RollController inMemoryRolls({
  Settings? settings,
  TakeSnapshot? takeSnapshot,
  LocationSource? location,
}) => RollController.inMemory(
  settings: settings ?? Settings.inMemory(),
  snapshots: SnapshotStore(Directory.systemTemp.createTempSync('grain-test')),
  takeSnapshot: takeSnapshot,
  location: location,
);
