import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The ABI codes android/app/build.gradle.kts adds to `build number * 1000`.
Map<String, int> _gradleAbiCodes() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final map = RegExp(r'val grainAbiCodes = mapOf\(([^)]*)\)').firstMatch(gradle);
  expect(map, isNotNull, reason: 'grainAbiCodes in build.gradle.kts');
  return {
    for (final m in RegExp(r'"([\w-]+)" to (\d+)').allMatches(map![1]!))
      m[1]!: int.parse(m[2]!),
  };
}

void main() {
  test('split APKs get build number * 1000 + ABI code, ABI last', () {
    expect(_gradleAbiCodes(), {'armeabi-v7a': 1, 'arm64-v8a': 2, 'x86_64': 4});
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('return build * 1000 + abiCode'));
    expect(gradle, contains('output.versionCode.set(grainVersionCode(build, abi))'));
  });

  test('the release build is not obfuscated', () {
    for (final f in ['README.md', 'docs/release.md']) {
      final builds = File(f)
          .readAsLinesSync()
          .where((l) => l.contains('flutter build') || l.contains('build apk'));
      expect(builds, isNotEmpty, reason: f);
      for (final l in builds) {
        expect(l, isNot(contains('--obfuscate')), reason: '$f: $l');
        expect(l, isNot(contains('--split-debug-info')), reason: '$f: $l');
      }
    }
  });
}
