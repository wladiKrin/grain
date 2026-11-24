import 'dart:io';

import 'package:grain/gear/platform.dart';
import 'package:grain/gear/save.dart';

/// Records shared `(fileName, text)` and returns a preset pick result.
class FakeGearPlatform implements GearPlatform {
  FakeGearPlatform({this.picked});

  final shared = <(String, String)>[];
  String? picked;
  Object? pickError;
  final sharedPaths = <List<String>>[];
  final sharedSubjects = <String>[];
  String? pickedPath;
  Directory? exportDir;

  @override
  Future<void> shareFile({
    required String fileName,
    required String text,
  }) async {
    shared.add((fileName, text));
  }

  @override
  Future<String?> pickTextFile() async {
    if (pickError != null) throw pickError!;
    return picked;
  }

  @override
  Future<void> sharePaths(List<String> paths, {required String subject}) async {
    sharedPaths.add(paths);
    sharedSubjects.add(subject);
  }

  /// Records `(name, mime)` per saved file; returns [saveResult], or [Saved]
  /// of the names when null.
  final saves = <List<(String, String)>>[];
  SaveResult? saveResult;

  @override
  Future<SaveResult> saveFiles(List<String> paths) async {
    final names = [for (final p in paths) p.split('/').last];
    saves.add([for (final n in names) (n, mimeOf(n))]);
    return saveResult ?? Saved(names);
  }

  @override
  Future<String?> pickFilePath() async => pickedPath;

  final discarded = <String>[];

  @override
  Future<void> discardPicked(String path) async => discarded.add(path);

  @override
  Future<Directory> exportDirectory() async {
    final d = exportDir ?? Directory.systemTemp.createTempSync('grain-export');
    exportDir = d;
    return d;
  }
}
