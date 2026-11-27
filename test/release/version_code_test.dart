import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The ABI codes android/app/build.gradle.kts adds to `build number * 1000`.
Map<String, int> _gradleAbiCodes() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final map = RegExp(r'val grainAbiCodes = mapOf\(([^)]*)\)')
      .firstMatch(gradle);
  expect(map, isNotNull, reason: 'grainAbiCodes in build.gradle.kts');
  return {
    for (final m in RegExp(r'"([\w-]+)" to (\d+)').allMatches(map![1]!))
      m[1]!: int.parse(m[2]!),
  };
}

const _recipe = 'docs/fdroid/io.github.wladikrin.grain.yml';

void main() {
  test('split APKs get build number * 1000 + ABI code, ABI last', () {
    expect(_gradleAbiCodes(), {'armeabi-v7a': 1, 'arm64-v8a': 2, 'x86_64': 4});
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('return build * 1000 + abiCode'));
    expect(
      gradle,
      contains('output.versionCode.set(grainVersionCode(build, abi))'),
    );
  });

  test('the F-Droid recipe follows the versionCode scheme', () {
    final codes = _gradleAbiCodes();
    final recipe = File(_recipe).readAsStringSync();
    final builds = RegExp(
      r'^  - versionName: (\S+)\n    versionCode: (\d+)\n    commit: ([0-9a-f]{40})\n'
      r'    output: build/app/outputs/flutter-apk/app-([\w-]+)-release\.apk\n'
      r'    binary: ?\n?\s*(\S+)\n',
      multiLine: true,
    ).allMatches(recipe).toList();
    expect(builds.map((b) => b[4]), ['armeabi-v7a', 'arm64-v8a', 'x86_64']);
    final buildNumber = int.parse(builds.first[2]!) ~/ 1000;
    for (final b in builds) {
      final abi = b[4]!;
      expect(int.parse(b[2]!), buildNumber * 1000 + codes[abi]!, reason: abi);
      expect(b[1], builds.first[1]);
      expect(b[3], builds.first[3]);
      expect(
        b[5],
        'https://github.com/wladiKrin/grain/releases/download/v%v/grain-%v-$abi.apk',
      );
      expect(
        recipe,
        contains(
          '--split-per-abi --target-platform=android-'
          '${{'armeabi-v7a': 'arm', 'arm64-v8a': 'arm64', 'x86_64': 'x64'}[abi]}\n',
        ),
      );
    }
    final ops = RegExp(
      r"^  - '%c \* 1000 \+ (\d)'$",
      multiLine: true,
    ).allMatches(recipe).map((m) => int.parse(m[1]!));
    expect(ops, [for (final b in builds) codes[b[4]]!]);
    expect(
      RegExp(
        r'^CurrentVersionCode: (\d+)$',
        multiLine: true,
      ).firstMatch(recipe)![1],
      builds.last[2],
    );
    expect(
      recipe,
      matches(
        RegExp(r'^AllowedAPKSigningKeys: [0-9a-f]{64}$', multiLine: true),
      ),
    );
    expect(recipe, isNot(contains('sudo:')));
  });

  test('the release build is not obfuscated', () {
    for (final f in [_recipe, 'README.md', 'docs/release.md']) {
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
