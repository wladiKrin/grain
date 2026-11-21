import 'dart:convert';

import '../rolls/codec.dart';
import '../rolls/model.dart';
import 'backup.dart';

/// A snapshot file name as the app makes them: `<uuid>.jpg`, lower case.
/// Nothing else is ever read from or written into the snapshots directory.
final snapshotNamePattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$',
);

bool isSnapshotName(String name) => snapshotNamePattern.hasMatch(name);

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

class ImportReport {
  const ImportReport({
    this.rollsAdded = 0,
    this.rollsCopied = 0,
    this.rollsSkipped = 0,
    this.rollsDeactivated = 0,
    this.readingsAdded = 0,
    this.readingsCopied = 0,
    this.readingsSkipped = 0,
    this.profilesAdded = 0,
    this.profilesCopied = 0,
    this.profilesSkipped = 0,
    this.snapshotsAdded = 0,
  });

  final int rollsAdded, rollsCopied, rollsSkipped, rollsDeactivated;
  final int readingsAdded, readingsCopied, readingsSkipped;
  final int profilesAdded, profilesCopied, profilesSkipped;
  final int snapshotsAdded;

  ImportReport withProfiles({
    required int added,
    required int copied,
    required int skipped,
  }) => ImportReport(
    rollsAdded: rollsAdded,
    rollsCopied: rollsCopied,
    rollsSkipped: rollsSkipped,
    rollsDeactivated: rollsDeactivated,
    readingsAdded: readingsAdded,
    readingsCopied: readingsCopied,
    readingsSkipped: readingsSkipped,
    profilesAdded: added,
    profilesCopied: copied,
    profilesSkipped: skipped,
    snapshotsAdded: snapshotsAdded,
  );

  String get summary {
    final b = StringBuffer(
      'Added ${_count(rollsAdded, 'roll', 'rolls')}, '
      '${_count(readingsAdded, 'saved reading', 'saved readings')}, '
      '${_count(profilesAdded, 'profile', 'profiles')}.',
    );
    final copies = rollsCopied + readingsCopied + profilesCopied;
    if (copies == 1) {
      b.write(' Kept 1 as a copy because it differs from what is here.');
    } else if (copies > 1) {
      b.write(' Kept $copies as copies because they differ from what is here.');
    }
    final skipped = rollsSkipped + readingsSkipped + profilesSkipped;
    if (skipped > 0) b.write(' Skipped $skipped already on this phone.');
    if (rollsDeactivated == 1) {
      b.write(' 1 imported active roll is now finished.');
    } else if (rollsDeactivated > 1) {
      b.write(' $rollsDeactivated imported active rolls are now finished.');
    }
    return b.toString();
  }
}

/// What an import writes: only new records (added, or copies with fresh
/// ids); nothing here is ever overwritten.
class MergePlan {
  const MergePlan({
    required this.rolls,
    required this.readings,
    required this.snapshots,
    required this.report,
  });

  final List<(Roll, List<Frame>)> rolls;
  final List<SavedReading> readings;

  /// Backup snapshot name → name to store it under here.
  final Map<String, String> snapshots;
  final ImportReport report;
}

String _json(Object? o) => jsonEncode(o);

/// Plans an import of [incoming] against what is here.
///
/// Same id and identical content (after [profileIds] remapping; a roll's
/// active/finished status is not compared) → skipped. Same id, different
/// content → stored as a copy with new ids for the record (and a roll's
/// frames). New id → added. At most one roll is active afterwards: an
/// imported active roll is stored finished when another is active.
///
/// [localSnapshots] lists snapshot names that already have a file here:
/// true when its bytes equal the backup's, false otherwise. A snapshot whose
/// name is referenced here or whose file here differs is stored under a new
/// name, so two records never share a file.
MergePlan planMerge({
  required List<(Roll, List<Frame>)> localRolls,
  required List<SavedReading> localReadings,
  required BackupContents incoming,
  required Map<String, String> profileIds,
  required String Function() newId,
  Map<String, bool> localSnapshots = const {},
}) {
  final rollsHere = {for (final r in localRolls) r.$1.id: r};
  final readingsHere = {for (final r in localReadings) r.id: r};
  final frameIds = {
    for (final r in localRolls)
      for (final f in r.$2) f.id,
  };
  final referenced = {
    for (final r in localRolls)
      for (final f in r.$2) ?f.snapshot,
    for (final r in localReadings) ?r.snapshot,
  };
  var activeHere = localRolls.any((r) => r.$1.isActive);

  String? body(String? id) => id == null ? null : profileIds['body:$id'] ?? id;
  Exposure lens(Exposure e) => e.lensId == null
      ? e
      : e.copyWith(lensId: () => profileIds['lens:${e.lensId}'] ?? e.lensId);

  final snapshots = <String, String>{};
  String? snapshot(String? name) {
    if (name == null) return null;
    final here = localSnapshots[name];
    final clash = referenced.contains(name) || here == false;
    if (!incoming.snapshotNames.contains(name)) {
      // Not in the backup (missing when exported): keep the reference as it
      // was there, unless that would point at a picture here.
      return clash || here != null ? null : name;
    }
    final mapped = snapshots[name];
    if (mapped != null) return mapped;
    if (!clash) {
      if (here == true) return name; // the same file is already here
      return snapshots[name] = name;
    }
    return snapshots[name] = '${newId()}.jpg';
  }

  var rollsAdded = 0, rollsCopied = 0, rollsSkipped = 0, deactivated = 0;
  final rolls = <(Roll, List<Frame>)>[];
  for (final (r0, f0) in incoming.rolls) {
    final r = r0.copyWith(bodyId: () => body(r0.bodyId));
    final frames = [for (final f in f0) f.copyWith(exposure: lens(f.exposure))];
    final local = rollsHere[r.id];
    if (local != null && _sameRoll((r, frames), local)) {
      rollsSkipped++;
      continue;
    }
    final copy = local != null;
    final id = copy ? newId() : r.id;
    var out = r.copyWith(id: id);
    final outFrames = <Frame>[];
    for (final f in frames) {
      final fid = copy || frameIds.contains(f.id) ? newId() : f.id;
      frameIds.add(fid);
      outFrames.add(
        f.copyWith(id: fid, rollId: id, snapshot: () => snapshot(f.snapshot)),
      );
    }
    if (out.isActive) {
      if (activeHere) {
        out = out.copyWith(
          status: RollStatus.finished,
          finishedAt: () => _lastTaken(outFrames) ?? out.startedAt,
        );
        deactivated++;
      } else {
        activeHere = true;
      }
    }
    copy ? rollsCopied++ : rollsAdded++;
    rolls.add((out, outFrames));
  }

  var readingsAdded = 0, readingsCopied = 0, readingsSkipped = 0;
  final readings = <SavedReading>[];
  for (final s0 in incoming.readings) {
    final s = s0.copyWith(
      bodyId: () => body(s0.bodyId),
      exposure: lens(s0.exposure),
    );
    final local = readingsHere[s.id];
    if (local != null &&
        _json(readingToJson(s)) == _json(readingToJson(local))) {
      readingsSkipped++;
      continue;
    }
    final copy = local != null;
    copy ? readingsCopied++ : readingsAdded++;
    readings.add(
      s.copyWith(
        id: copy ? newId() : s.id,
        snapshot: () => snapshot(s.snapshot),
      ),
    );
  }

  return MergePlan(
    rolls: rolls,
    readings: readings,
    snapshots: snapshots,
    report: ImportReport(
      rollsAdded: rollsAdded,
      rollsCopied: rollsCopied,
      rollsSkipped: rollsSkipped,
      rollsDeactivated: deactivated,
      readingsAdded: readingsAdded,
      readingsCopied: readingsCopied,
      readingsSkipped: readingsSkipped,
      snapshotsAdded: snapshots.length,
    ),
  );
}

DateTime? _lastTaken(List<Frame> frames) {
  for (final f in frames.reversed) {
    if (f.takenAt != null) return f.takenAt;
  }
  return null;
}

/// Equal as exported. When only one of the two is active, status and
/// finishing time are left out: the same roll restored where another roll
/// was active is stored finished, and must still match on the way back.
bool _sameRoll((Roll, List<Frame>) a, (Roll, List<Frame>) b) {
  var (ra, fa) = a;
  var (rb, fb) = b;
  if (ra.status != rb.status) {
    ra = ra.copyWith(status: RollStatus.finished, finishedAt: () => null);
    rb = rb.copyWith(status: RollStatus.finished, finishedAt: () => null);
  }
  return _json(rollToJson(ra, fa)) == _json(rollToJson(rb, fb));
}
