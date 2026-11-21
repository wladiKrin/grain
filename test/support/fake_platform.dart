import 'package:grain/gear/platform.dart';

/// Records shared `(fileName, text)` and returns a preset pick result.
class FakeGearPlatform implements GearPlatform {
  FakeGearPlatform({this.picked});

  final shared = <(String, String)>[];
  String? picked;
  Object? pickError;

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
}
