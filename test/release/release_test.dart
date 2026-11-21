import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/version.dart';

void main() {
  test('version is 1.0.0 build 1 everywhere', () {
    expect(
      RegExp(r'^version: (.+)$', multiLine: true)
          .firstMatch(File('pubspec.yaml').readAsStringSync())!
          .group(1),
      '$appVersion+1',
    );
    expect(appVersion, '1.0.0');
    expect(
      File('fastlane/metadata/android/en-US/changelogs/1.txt').existsSync(),
      isTrue,
    );
  });

  test('store texts fit F-Droid limits', () {
    String t(String f) =>
        File('fastlane/metadata/android/en-US/$f').readAsStringSync().trim();
    expect(t('title.txt'), 'Grain');
    expect(t('short_description.txt').length, inInclusiveRange(1, 80));
    expect(t('full_description.txt').length, inInclusiveRange(1, 4000));
    expect(t('changelogs/1.txt').length, inInclusiveRange(1, 500));
  });

  test('store icon is a 512 px PNG', () {
    final b = File('fastlane/metadata/android/en-US/images/icon.png')
        .readAsBytesSync();
    expect(b.sublist(1, 4), 'PNG'.codeUnits);
    final d = ByteData.sublistView(b);
    expect([d.getUint32(16), d.getUint32(20)], [512, 512]);
  });

  test('adaptive icon with a monochrome layer, no Flutter logo left', () {
    final xml = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
        .readAsStringSync();
    expect(
      xml,
      allOf(contains('<monochrome'), contains('@drawable/ic_launcher_foreground')),
    );
    final pngs = Directory('android/app/src/main/res')
        .listSync(recursive: true)
        .where((f) => f.path.endsWith('ic_launcher.png'));
    expect(pngs, isEmpty);
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:roundIcon="@mipmap/ic_launcher_round"'),
    );
  });

  test('signing reads key.properties, secrets stay ignored', () {
    final g = File('android/app/build.gradle.kts').readAsStringSync();
    expect(g, allOf(contains('key.properties'), contains('GRAIN_UNSIGNED')));
    final ignore = File('android/.gitignore').readAsStringSync();
    expect(ignore, allOf(contains('key.properties'), contains('*.jks')));
  });
}
