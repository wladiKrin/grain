import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the release manifest asks for these permissions and no others', () {
    final m = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final asked = RegExp(r'<uses-permission android:name="([^"]+)"')
        .allMatches(m)
        .map((x) => x[1])
        .toList();
    expect(asked, [
      'android.permission.CAMERA',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_FINE_LOCATION',
      // The map's opt-in OpenStreetMap tiles only (Settings > Online map).
      'android.permission.INTERNET',
    ]);
  });
}
