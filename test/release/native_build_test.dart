import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/db/database.dart';

void main() {
  test('SQLite comes from the vendored amalgamation', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('source: source'));
    expect(pubspec, contains('path: third_party/sqlite/sqlite3.c'));
    final version = File('third_party/sqlite/VERSION')
        .readAsStringSync()
        .trim();
    expect(
      File('third_party/sqlite/sqlite3.c').readAsStringSync(),
      contains('#define SQLITE_VERSION        "$version"'),
    );
  });

  test('the loaded SQLite is the vendored one', () async {
    final db = GrainDatabase(NativeDatabase.memory());
    final v = await db.customSelect('select sqlite_version() as v').getSingle();
    expect(
      v.read<String>('v'),
      File('third_party/sqlite/VERSION').readAsStringSync().trim(),
    );
    await db.close();
  });

  test('bundled fonts are subsets under the OFL', () {
    for (final w in ['Light', 'Regular', 'Medium', 'SemiBold']) {
      expect(
        File('assets/fonts/InterTight-$w.ttf').lengthSync(),
        lessThan(120000),
      );
    }
    final head = File('assets/fonts/OFL.txt')
        .readAsLinesSync()
        .take(6)
        .join('\n');
    expect(head, contains('SIL Open Font License'));
    expect(head, isNot(contains('Reserved Font Name')));
  });
}
