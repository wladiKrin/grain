import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The directory holding frame and reading snapshots, addressed by file name.
class SnapshotStore {
  SnapshotStore(this.dir);

  static Future<SnapshotStore> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/snapshots');
    await dir.create(recursive: true);
    return SnapshotStore(dir);
  }

  final Directory dir;

  File file(String name) => File('${dir.path}/$name');

  Future<bool> exists(String name) => file(name).exists();

  /// A missing file is fine.
  Future<void> delete(String name) async {
    try {
      await file(name).delete();
    } on FileSystemException {
      // already gone, or not removable: nothing more to do
    }
  }
}
