import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

import '../gear/ids.dart';
import 'codec.dart';
import 'model.dart';
import 'snapshot_store.dart';

String rollFileBase(Roll r) => 'roll-${r.number}-${slugify(r.filmStock)}';

/// Writes `<base>.csv`, `<base>.json` and, with [withSnapshots] and at least
/// one snapshot file present, `<base>-snapshots.zip` into [out]. The zip is
/// built in a background isolate and streams from disk.
Future<List<File>> exportRoll(
  Roll r,
  List<Frame> frames, {
  required Directory out,
  required SnapshotStore store,
  required bool withSnapshots,
}) async {
  final base = rollFileBase(r);
  await out.create(recursive: true);
  final csv = File('${out.path}/$base.csv');
  final json = File('${out.path}/$base.json');
  await csv.writeAsString(rollToCsv(r, frames));
  await json.writeAsString(
    const JsonEncoder.withIndent('  ').convert(rollToJson(r, frames)),
  );
  final files = [csv, json];
  if (withSnapshots) {
    final entries = <(String, String)>[]; // (source path, entry name)
    final used = <String, int>{};
    for (final f in frames) {
      final name = f.snapshot;
      if (name == null || !await store.exists(name)) continue;
      final n = used.update(f.label, (c) => c + 1, ifAbsent: () => 1);
      final label = n == 1 ? f.label : '${f.label}-$n';
      entries.add((store.file(name).path, 'frame-$label.jpg'));
    }
    if (entries.isNotEmpty) {
      final zip = File('${out.path}/$base-snapshots.zip');
      await Isolate.run(() => _zip(zip.path, entries));
      files.add(zip);
    }
  }
  return files;
}

Future<void> _zip(String path, List<(String, String)> entries) async {
  final enc = ZipFileEncoder()..create(path);
  try {
    for (final (src, name) in entries) {
      try {
        await enc.addFile(File(src), name);
      } on FileSystemException {
        // vanished since the check: skip it
      }
    }
  } finally {
    await enc.close();
  }
}
