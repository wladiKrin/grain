import 'dart:convert';

import '../rolls/codec.dart';
import '../rolls/model.dart';
import 'contents.dart';

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

  ImportReport copyWith({
    int? rollsDeactivated,
    int? profilesAdded,
    int? profilesCopied,
    int? profilesSkipped,
  }) => ImportReport(
    rollsAdded: rollsAdded,
    rollsCopied: rollsCopied,
    rollsSkipped: rollsSkipped,
    rollsDeactivated: rollsDeactivated ?? this.rollsDeactivated,
    readingsAdded: readingsAdded,
    readingsCopied: readingsCopied,
    readingsSkipped: readingsSkipped,
    profilesAdded: profilesAdded ?? this.profilesAdded,
    profilesCopied: profilesCopied ?? this.profilesCopied,
    profilesSkipped: profilesSkipped ?? this.profilesSkipped,
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
    this.restores = const {},
    required this.report,
  });

  final List<(Roll, List<Frame>)> rolls;
  final List<SavedReading> readings;

  /// Backup snapshot name → name to store it under here, for the records
  /// in this plan.
  final Map<String, String> snapshots;

  /// Snapshot files missing here for records that were skipped as already
  /// here: name here → backup name to copy it from (restores thumbnails
  /// after a system restore, which leaves the snapshot files out).
  final Map<String, String> restores;
  final ImportReport report;
}

String _json(Object? o) => jsonEncode(o);

final _epoch = DateTime.utc(1970);

/// When a roll finished by an import ends: its latest frame time, else its
/// start.
DateTime finishTimeFor(Roll r, List<Frame> frames) {
  DateTime? last;
  for (final f in frames) {
    final t = f.takenAt;
    if (t != null && (last == null || t.isAfter(last))) last = t;
  }
  return last ?? r.startedAt;
}

/// A roll as compared on import (frame cameras included; an older backup's
/// frames take the roll's camera, as the v4 database did for frames here):
/// ids, frames' roll ids, snapshot names and
/// every updatedAt left out (ids and names change when a record is copied or
/// a snapshot renamed; a snapshot is an attachment, not part of the log;
/// updatedAt moves on a no-op save or a snapshot delete). [loose] also leaves
/// out status and finishing time, which finishing a roll changes.
String _rollKey(Roll r, List<Frame> frames, {required bool loose}) {
  var k = r.copyWith(id: '', updatedAt: _epoch);
  if (loose) {
    k = k.copyWith(status: RollStatus.finished, finishedAt: () => null);
  }
  return _json(
    rollToJson(k, [
      for (final f in frames)
        f.copyWith(id: '', rollId: '', snapshot: () => null, updatedAt: _epoch),
    ]),
  );
}

String _readingKey(SavedReading s) => _json(
  readingToJson(s.copyWith(id: '', snapshot: () => null, updatedAt: _epoch)),
);

/// The same roll: identical content; when only one of the two is active,
/// the active/finished difference (status, finishedAt) is not
/// compared, so a roll finished here since the backup, or restored finished
/// because another roll was active, still matches (R4).
bool _sameRoll((Roll, List<Frame>) a, (Roll, List<Frame>) b) {
  final loose = a.$1.status != b.$1.status;
  return _rollKey(a.$1, a.$2, loose: loose) ==
      _rollKey(b.$1, b.$2, loose: loose);
}

/// Plans an import of [incoming] against what is here.
///
/// Same id and the same content (after [profileIds] remapping; see
/// [_sameRoll]) → skipped. Same id, different content → stored as a copy
/// with new ids for the record (and a roll's frames), unless an earlier
/// import already stored such a copy (then skipped). New id → added. At most
/// one roll is active afterwards: an imported active roll is stored finished
/// when another is active.
///
/// [localSnapshots] has an entry for each snapshot name that has a file here:
/// true when its bytes equal the backup's, false otherwise. A snapshot whose
/// name is referenced here or whose file here differs is stored under a new
/// name, so two records never share a file. For skipped records, snapshot
/// files missing here are restored from the backup ([MergePlan.restores]).
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
  // Content index for finding a copy stored by an earlier import.
  final rollsByKey = <String, List<(Roll, List<Frame>)>>{};
  for (final r in localRolls) {
    (rollsByKey[_rollKey(r.$1, r.$2, loose: true)] ??= []).add(r);
  }
  final readingsByKey = <String, SavedReading>{
    for (final r in localReadings) _readingKey(r): r,
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

  final restores = <String, String>{};
  void restore(String? here, String? source) {
    if (here == null || source == null) return;
    if (localSnapshots.containsKey(here) || restores.containsKey(here)) return;
    if (!isSnapshotName(here) || !incoming.snapshotNames.contains(source)) {
      return;
    }
    restores[here] = source;
  }

  var rollsAdded = 0, rollsCopied = 0, rollsSkipped = 0, deactivated = 0;
  final rolls = <(Roll, List<Frame>)>[];
  for (final (r0, f0) in incoming.rolls) {
    final r = r0.copyWith(bodyId: () => body(r0.bodyId));
    final frames = [
      for (final f in f0)
        f.copyWith(bodyId: () => body(f.bodyId), exposure: lens(f.exposure)),
    ];
    final local = rollsHere[r.id];
    final match = local == null
        ? null
        : _sameRoll((r, frames), local)
        ? local
        : rollsByKey[_rollKey(r, frames, loose: true)]
              ?.where((c) => _sameRoll((r, frames), c))
              .firstOrNull;
    if (match != null) {
      for (var i = 0; i < frames.length; i++) {
        restore(match.$2[i].snapshot, frames[i].snapshot);
      }
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
          finishedAt: () => finishTimeFor(out, outFrames),
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
    final match = local == null ? null : readingsByKey[_readingKey(s)];
    if (match != null) {
      restore(match.snapshot, s.snapshot);
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
    restores: restores,
    report: ImportReport(
      rollsAdded: rollsAdded,
      rollsCopied: rollsCopied,
      rollsSkipped: rollsSkipped,
      rollsDeactivated: deactivated,
      readingsAdded: readingsAdded,
      readingsCopied: readingsCopied,
      readingsSkipped: readingsSkipped,
      snapshotsAdded: snapshots.length + restores.length,
    ),
  );
}
