import 'dart:io';

import 'package:grain/gear/platform.dart';

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
