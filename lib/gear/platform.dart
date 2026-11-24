import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'codec.dart';
import 'save.dart';

/// The two platform touchpoints of sharing; replaced by a fake in tests.
abstract class GearPlatform {
  /// Offers [text] as a JSON file named [fileName] to the share sheet.
  Future<void> shareFile({required String fileName, required String text});

  /// Lets the user pick a file and returns its text; null when cancelled.
  /// Throws [GearFormatException] for a file that is too large.
  Future<String?> pickTextFile();

  /// Offers the files at [paths] to the share sheet.
  Future<void> sharePaths(List<String> paths, {required String subject});

  /// Copies the files at [paths] to a place the user picks: a new file for
  /// one, a folder for several.
  Future<SaveResult> saveFiles(List<String> paths);

  /// Lets the user pick a file and returns a readable path; null when
  /// cancelled.
  Future<String?> pickFilePath();

  /// Done with a path from [pickFilePath]: removes it if it is a temporary
  /// copy made by the pick (never the user's own file).
  Future<void> discardPicked(String path);

  /// An empty `<temp>/exports` directory for files about to be shared.
  Future<Directory> exportDirectory();
}

class SystemGearPlatform implements GearPlatform {
  const SystemGearPlatform();

  static const maxBytes = 256 * 1024;

  @override
  Future<void> shareFile({
    required String fileName,
    required String text,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    await File(path).writeAsString(text);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/json')],
        subject: fileName,
      ),
    );
  }

  @override
  Future<String?> pickTextFile() async {
    // No type filter: Android providers often mislabel JSON.
    final file = await openFile();
    if (file == null) return null;
    if (await file.length() > maxBytes) {
      throw GearFormatException(['file: larger than 256 KB']);
    }
    return file.readAsString();
  }

  @override
  Future<void> sharePaths(List<String> paths, {required String subject}) =>
      SharePlus.instance.share(
        ShareParams(files: [for (final p in paths) XFile(p)], subject: subject),
      );

  @override
  Future<SaveResult> saveFiles(List<String> paths) => const SaveChannel().save([
    for (final p in paths) (path: p, name: p.substring(p.lastIndexOf('/') + 1)),
  ]);

  @override
  Future<String?> pickFilePath() async {
    final file = await openFile();
    if (file == null) return null;
    if (await File(file.path).exists()) return file.path;
    final dir = await getTemporaryDirectory();
    final copy = File(
      '${dir.path}/picked-${DateTime.now().microsecondsSinceEpoch}',
    );
    // Streamed: a backup can be large.
    final sink = copy.openWrite();
    try {
      await sink.addStream(file.openRead());
    } finally {
      await sink.close();
    }
    return copy.path;
  }

  @override
  Future<void> discardPicked(String path) async {
    final dir = await getTemporaryDirectory();
    final name = path.substring(path.lastIndexOf('/') + 1);
    if (path != '${dir.path}/$name' || !name.startsWith('picked-')) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // already gone
    }
  }

  @override
  Future<Directory> exportDirectory() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/exports');
    if (await dir.exists()) await dir.delete(recursive: true);
    return dir.create(recursive: true);
  }
}
