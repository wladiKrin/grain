import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _rules = [
  '<include domain="root" path="app_flutter/grain.sqlite"/>',
  '<include domain="root" path="app_flutter/grain.sqlite-wal"/>',
  '<include domain="root" path="app_flutter/grain.sqlite-journal"/>',
  '<include domain="sharedpref" path="FlutterSharedPreferences.xml"/>',
  '<exclude domain="file" path="snapshots/"/>',
];

int _count(String s, String sub) => sub.allMatches(s).length;

void main() {
  const res = 'android/app/src/main/res/xml';

  test('backup_rules.xml has the includes and the snapshots exclude', () {
    final xml = File('$res/backup_rules.xml').readAsStringSync();
    expect(xml, contains('<full-backup-content>'));
    for (final r in _rules) {
      expect(_count(xml, r), 1, reason: r);
    }
  });

  test('data_extraction_rules.xml repeats the rules in both sections', () {
    final xml = File('$res/data_extraction_rules.xml').readAsStringSync();
    expect(xml, contains('<data-extraction-rules>'));
    for (final section in ['cloud-backup', 'device-transfer']) {
      final start = xml.indexOf('<$section>');
      final end = xml.indexOf('</$section>');
      expect(start, greaterThanOrEqualTo(0), reason: section);
      expect(end, greaterThan(start), reason: section);
      final body = xml.substring(start, end);
      for (final r in _rules) {
        expect(_count(body, r), 1, reason: '$section: $r');
      }
    }
  });

  test('manifest references both resources and keeps backup on', () {
    final m = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(m, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      m,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(m, contains('android:allowBackup="true"'));
    expect(m, isNot(contains('allowBackup="false"')));
  });

  test('storage names the rules depend on still hold', () {
    expect(
      File('lib/db/database.dart').readAsStringSync(),
      contains("driftDatabase(name: 'grain')"),
    );
    expect(
      File('lib/settings/settings.dart').readAsStringSync(),
      contains('SharedPreferences.getInstance()'),
    );
  });
}
