import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the release manifest asks for these permissions and no others', () {
    final m = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final tags = RegExp(r'<uses-permission[^>]*>')
        .allMatches(m)
        .map((x) => x[0]!);
    String name(String tag) =>
        RegExp(r'android:name="([^"]+)"').firstMatch(tag)![1]!;
    final asked = [
      for (final t in tags)
        if (!t.contains('tools:node="remove"')) name(t),
    ];
    final removed = [
      for (final t in tags)
        if (t.contains('tools:node="remove"')) name(t),
    ];
    expect(asked, [
      'android.permission.CAMERA',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_FINE_LOCATION',
      // The map's opt-in online tiles only (Settings > Map).
      'android.permission.INTERNET',
    ]);
    // MapLibre's manifest asks for these; Grain takes them out (MapLibre is
    // told the network state instead, MapNetPlugin.kt).
    expect(removed, [
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.ACCESS_WIFI_STATE',
    ]);
  });
}
