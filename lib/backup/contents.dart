import 'dart:isolate';

import 'package:archive/archive_io.dart';

import '../gear/model.dart';
import '../rolls/model.dart';

/// Zip folder of the snapshot files in a backup.
const snapshotEntryDir = 'snapshots/';

/// Larger snapshot entries are not read; a snapshot is a few hundred KB.
const maxSnapshotBytes = 16 * 1024 * 1024;

/// A backup as read from its zip. The JSON is parsed up front; snapshot
/// bytes stay in the zip until asked for.
class BackupContents {
  BackupContents({
    this.profiles = const [],
    this.favorites = const {},
    this.rolls = const [],
    this.readings = const [],
    this.settings = const {},
    this.snapshotNames = const {},
    this.zipPath,
  });

  final List<GearProfile> profiles;
  final Map<ProfileKind, Set<String>> favorites;
  final List<(Roll, List<Frame>)> rolls;
  final List<SavedReading> readings;
  final Map<String, Object?> settings;

  /// Snapshot files present in the zip (valid names only).
  final Set<String> snapshotNames;

  /// The zip this was read from; null for contents built in memory.
  final String? zipPath;

  /// The bytes of snapshot [name], or null when the backup has none.
  Future<List<int>?> snapshot(String name) async {
    final path = zipPath;
    if (path == null || !snapshotNames.contains(name)) return null;
    return Isolate.run(() => readZipEntry(path, '$snapshotEntryDir$name'));
  }
}

/// One entry of the zip at [zipPath], or null when missing or too large.
/// Synchronous: call it in a background isolate.
List<int>? readZipEntry(String zipPath, String name) {
  final input = InputFileStream(zipPath);
  try {
    final f = ZipDecoder().decodeStream(input).findFile(name);
    if (f == null || f.size > maxSnapshotBytes) return null;
    return f.readBytes();
  } finally {
    input.closeSync();
  }
}
