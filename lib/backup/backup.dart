import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

import '../gear/codec.dart';
import '../gear/gear_controller.dart';
import '../gear/model.dart';
import '../rolls/codec.dart';
import '../rolls/ids.dart' as ids;
import '../rolls/model.dart';
import '../rolls/roll_controller.dart';
import '../settings/settings.dart';
import '../settings/settings_screen.dart' show appVersion;
import 'merge.dart';

export 'merge.dart' show ImportReport, MergePlan, planMerge;

const backupEntry = 'grain-backup.json';
const _snapshotDir = 'snapshots/';

/// Larger entries are not read: the JSON of tens of thousands of frames is
/// well below this, and a snapshot is a few hundred KB at most.
const _maxJsonBytes = 64 * 1024 * 1024;
const _maxSnapshotBytes = 16 * 1024 * 1024;

class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

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
    return Isolate.run(() => _readEntry(path, '$_snapshotDir$name'));
  }
}

// ---- export ----------------------------------------------------------------

String _two(int n) => n.toString().padLeft(2, '0');

String backupFileName(DateTime now) =>
    'grain-backup-${now.year}-${_two(now.month)}-${_two(now.day)}.zip';

/// Writes everything into `grain-backup-<date>.zip` in [out]. The zip is
/// built in a background isolate, streaming snapshots from disk; snapshot
/// files that are gone are left out.
Future<File> writeBackup({
  required Directory out,
  required GearController gear,
  required RollController rolls,
  required Settings settings,
  required DateTime now,
}) async {
  final all = await rolls.allFrames();
  final readings = rolls.readings;
  final names = <String>{
    for (final (_, frames) in all)
      for (final f in frames)
        if (f.snapshot != null && isSnapshotName(f.snapshot!)) f.snapshot!,
    for (final r in readings)
      if (r.snapshot != null && isSnapshotName(r.snapshot!)) r.snapshot!,
  };
  final doc = <String, Object?>{
    'schema': 1,
    'type': 'grain-backup',
    'exportedAt': isoWithOffset(now, now.timeZoneOffset.inMinutes),
    'app': appVersion,
    'profiles': [for (final p in gear.userProfiles) gearToJson(p)],
    'favorites': {
      'body': gear.favoriteIds(ProfileKind.body).toList()..sort(),
      'lens': gear.favoriteIds(ProfileKind.lens).toList()..sort(),
    },
    'rolls': [for (final (r, frames) in all) rollToJson(r, frames)],
    'readings': [for (final r in readings) readingToJson(r)],
    'settings': settings.backupMap(),
  };
  await out.create(recursive: true);
  final file = File('${out.path}/${backupFileName(now)}');
  final dir = rolls.snapshots.dir.path;
  final list = names.toList()..sort();
  await Isolate.run(() => _writeZip(file.path, doc, dir, list));
  return file;
}

Future<void> _writeZip(
  String path,
  Map<String, Object?> doc,
  String snapshotDir,
  List<String> names,
) async {
  final enc = ZipFileEncoder()..create(path);
  try {
    enc.addArchiveFile(
      ArchiveFile.string(
        backupEntry,
        const JsonEncoder.withIndent('  ').convert(doc),
      ),
    );
    for (final n in names) {
      final f = File('$snapshotDir/$n');
      if (!f.existsSync()) continue;
      try {
        await enc.addFile(f, '$_snapshotDir$n');
      } on FileSystemException {
        // vanished since the check: skip it
      }
    }
  } finally {
    await enc.close();
  }
}

// ---- reading ---------------------------------------------------------------

Never _notBackup() => throw BackupFormatException('Not a Grain backup');

Never _damaged(String detail) =>
    throw BackupFormatException('The backup is damaged: $detail');

/// Entry names that could reach outside a target directory.
bool _unsafe(String name) =>
    name.startsWith('/') ||
    name.contains('\\') ||
    name.contains('\u0000') ||
    RegExp(r'^[A-Za-z]:').hasMatch(name) ||
    name.split('/').contains('..');

/// Reads and checks a backup zip. Refuses (with [BackupFormatException]) a
/// file that is not a backup, comes from a newer version, is damaged, or
/// holds an entry with an unsafe path; nothing is changed then. The zip is
/// opened in a background isolate and streams from disk.
Future<BackupContents> readBackup(String zipPath) =>
    Isolate.run(() => _readBackup(zipPath));

BackupContents _readBackup(String path) {
  final input = InputFileStream(path);
  try {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } on Object {
      _notBackup();
    }
    ArchiveFile? json;
    final names = <String>{};
    for (final f in archive.files) {
      final n = f.name;
      if (_unsafe(n)) {
        throw BackupFormatException(
          'The backup contains an unsafe file name: $n',
        );
      }
      if (!f.isFile || f.isSymbolicLink) continue;
      if (n == backupEntry) {
        json = f;
      } else if (n.startsWith(_snapshotDir)) {
        final s = n.substring(_snapshotDir.length);
        if (isSnapshotName(s) && f.size <= _maxSnapshotBytes) names.add(s);
      }
    }
    if (json == null) _notBackup();
    if (json.size > _maxJsonBytes) {
      throw BackupFormatException('The backup is too large to read');
    }
    final Object? top;
    try {
      final bytes = json.readBytes();
      if (bytes == null) _notBackup();
      top = jsonDecode(utf8.decode(bytes));
    } on BackupFormatException {
      rethrow;
    } on Object {
      _notBackup();
    }
    return _parse(top, names, path);
  } finally {
    input.closeSync();
  }
}

List<Object?> _listAt(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v == null) return const [];
  return v is List ? v : _damaged('$key: expected a list');
}

void _checkSnapshot(String? name, String path) {
  if (name != null && !isSnapshotName(name)) {
    _damaged('$path.snapshot: not a snapshot name');
  }
}

BackupContents _parse(Object? json, Set<String> names, String zipPath) {
  if (json is! Map) _notBackup();
  final m = {for (final e in json.entries) e.key.toString(): e.value};
  if (m['type'] != 'grain-backup') _notBackup();
  final schema = m['schema'];
  if (schema is int && schema > 1) {
    throw BackupFormatException(
      'Made by a newer version of Grain (schema $schema)',
    );
  }
  if (schema != 1) _notBackup();

  final profiles = <GearProfile>[];
  final profileList = _listAt(m, 'profiles');
  final seenProfiles = <String>{};
  for (var i = 0; i < profileList.length; i++) {
    final GearDoc doc;
    try {
      doc = parseGear(profileList[i]);
    } on GearFormatException catch (e) {
      _damaged('profiles[$i]: ${e.errors.first}');
    }
    if (doc is! GearProfile) _damaged('profiles[$i]: not a body or lens');
    if (!seenProfiles.add('${doc.kind.name}:${doc.id}')) {
      _damaged('profiles[$i]: id "${doc.id}" appears twice');
    }
    profiles.add(doc);
  }

  final favorites = <ProfileKind, Set<String>>{};
  final fav = m['favorites'];
  if (fav != null) {
    if (fav is! Map) _damaged('favorites: expected an object');
    for (final kind in ProfileKind.values) {
      final ids = fav[kind.name];
      if (ids == null) continue;
      if (ids is! List || ids.any((x) => x is! String)) {
        _damaged('favorites.${kind.name}: expected a list of ids');
      }
      favorites[kind] = {for (final x in ids) x as String};
    }
  }

  final rolls = <(Roll, List<Frame>)>[];
  final rollIds = <String>{}, frameIds = <String>{};
  final rollList = _listAt(m, 'rolls');
  for (var i = 0; i < rollList.length; i++) {
    final (Roll, List<Frame>) r;
    try {
      r = rollFromJson(rollList[i]);
    } on RollFormatException catch (e) {
      _damaged('rolls[$i]: ${e.message}');
    }
    if (!rollIds.add(r.$1.id)) _damaged('rolls[$i]: id appears twice');
    for (var j = 0; j < r.$2.length; j++) {
      final f = r.$2[j];
      if (!frameIds.add(f.id)) {
        _damaged('rolls[$i].frames[$j]: id appears twice');
      }
      _checkSnapshot(f.snapshot, 'rolls[$i].frames[$j]');
    }
    rolls.add(r);
  }

  final readings = <SavedReading>[];
  final readingIds = <String>{};
  final readingList = _listAt(m, 'readings');
  for (var i = 0; i < readingList.length; i++) {
    final SavedReading r;
    try {
      r = readingFromJson(readingList[i]);
    } on RollFormatException catch (e) {
      _damaged('readings[$i]: ${e.message}');
    }
    if (!readingIds.add(r.id)) _damaged('readings[$i]: id appears twice');
    _checkSnapshot(r.snapshot, 'readings[$i]');
    readings.add(r);
  }

  final s = m['settings'];
  return BackupContents(
    profiles: profiles,
    favorites: favorites,
    rolls: rolls,
    readings: readings,
    settings: s is Map
        ? {for (final e in s.entries) e.key.toString(): e.value}
        : const {},
    snapshotNames: names,
    zipPath: zipPath,
  );
}

List<int>? _readEntry(String zipPath, String name) {
  final input = InputFileStream(zipPath);
  try {
    final f = ZipDecoder().decodeStream(input).findFile(name);
    if (f == null || f.size > _maxSnapshotBytes) return null;
    return f.readBytes();
  } finally {
    input.closeSync();
  }
}

// ---- import ----------------------------------------------------------------

/// For every snapshot name in the backup or its records that already has a
/// file here: whether that file's bytes equal the backup's.
Map<String, bool> _compareSnapshots(
  String zipPath,
  String dir,
  List<String> names,
  Set<String> inZip,
) {
  final out = <String, bool>{};
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    for (final n in names) {
      final here = File('$dir/$n');
      if (!here.existsSync()) continue;
      final entry = inZip.contains(n)
          ? archive.findFile('$_snapshotDir$n')
          : null;
      if (entry == null || entry.size != here.lengthSync()) {
        out[n] = false;
        continue;
      }
      out[n] = _sameBytes(
        entry.readBytes() ?? const [],
        here.readAsBytesSync(),
      );
    }
  } finally {
    input.closeSync();
  }
  return out;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Copies backup snapshots into [dir] (source → target name); an existing
/// file is never replaced. Returns the names written.
List<String> _copySnapshots(
  String zipPath,
  String dir,
  Map<String, String> plan,
) {
  final written = <String>[];
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    for (final MapEntry(key: src, value: target) in plan.entries) {
      if (!isSnapshotName(src) || !isSnapshotName(target)) continue;
      final dest = File('$dir/$target');
      if (dest.existsSync()) continue;
      final entry = archive.findFile('$_snapshotDir$src');
      if (entry == null || entry.size > _maxSnapshotBytes) continue;
      final bytes = entry.readBytes();
      if (bytes == null) continue;
      final part = File('$dir/.$target.part');
      part.writeAsBytesSync(bytes, flush: true);
      part.renameSync(dest.path);
      written.add(target);
    }
  } finally {
    input.closeSync();
  }
  return written;
}

/// Merges [c] into this phone: profiles first (their renames reach the
/// rolls and readings), then snapshot files, then all records in one
/// transaction. Settings (haptics, viewfinder, snapshots) are taken from the
/// file only with [applySettings]; calibration and location never travel.
Future<ImportReport> importBackup(
  BackupContents c, {
  required GearController gear,
  required RollController rolls,
  required Settings settings,
  required bool applySettings,
}) async {
  final profiles = await gear.mergeProfiles(c.profiles, c.favorites);
  final localRolls = await rolls.allFrames();
  final localReadings = rolls.readings;
  final dir = rolls.snapshots.dir.path;
  final zip = c.zipPath;
  final names = <String>{
    ...c.snapshotNames,
    for (final (_, frames) in c.rolls)
      for (final f in frames) ?f.snapshot,
    for (final r in c.readings) ?r.snapshot,
  }.where(isSnapshotName).toList();
  final inZip = c.snapshotNames;
  final localSnapshots = zip == null
      ? <String, bool>{}
      : await Isolate.run(() => _compareSnapshots(zip, dir, names, inZip));
  final plan = planMerge(
    localRolls: localRolls,
    localReadings: localReadings,
    incoming: c,
    profileIds: profiles.renames,
    newId: ids.newId,
    localSnapshots: localSnapshots,
  );
  final copies = plan.snapshots;
  final written = zip == null || copies.isEmpty
      ? const <String>[]
      : await Isolate.run(() => _copySnapshots(zip, dir, copies));
  try {
    await rolls.importRecords(plan);
  } on Object {
    for (final n in written) {
      await rolls.snapshots.delete(n);
    }
    rethrow;
  }
  if (applySettings) await settings.applyBackupMap(c.settings);
  return plan.report.withProfiles(
    added: profiles.added,
    copied: profiles.copied,
    skipped: profiles.skipped,
  );
}
