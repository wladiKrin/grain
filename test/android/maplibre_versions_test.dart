import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The maplibre_gl package's own directory, from the package config.
Directory _plugin() {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, Object?>;
  final entry = (config['packages']! as List)
      .cast<Map<String, Object?>>()
      .firstWhere((p) => p['name'] == 'maplibre_gl');
  final root = Uri.parse(entry['rootUri']! as String);
  return Directory.fromUri(
    root.isAbsolute ? root : File('.dart_tool/').uri.resolveUri(root),
  );
}

String? _version(String gradle, String artifact) =>
    RegExp('${RegExp.escape(artifact)}:([0-9.]+)').firstMatch(gradle)?[1];

void main() {
  test('the app builds MapNetPlugin against the MapLibre and OkHttp '
      'maplibre_gl brings', () {
    final plugin = File(
      '${_plugin().path}/android/build.gradle',
    ).readAsStringSync();
    final app = File('android/app/build.gradle.kts').readAsStringSync();
    for (final a in [
      'org.maplibre.gl:android-sdk-opengl',
      'com.squareup.okhttp3:okhttp',
    ]) {
      final want = _version(plugin, a);
      expect(want, isNotNull, reason: a);
      expect(_version(app, a), want, reason: a);
    }
    final notice = File('lib/settings/licences.dart').readAsStringSync();
    expect(
      notice,
      contains(
        'MapLibre Native for Android '
        '${_version(plugin, 'org.maplibre.gl:android-sdk-opengl')}',
      ),
    );
  });

  test('no Google Play Services: maplibre_gl builds without them', () {
    final props = File('android/gradle.properties').readAsStringSync();
    expect(props, contains('maplibre_gl.playServicesLocation=false'));
  });
}
