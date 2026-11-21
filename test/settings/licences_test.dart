import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/settings/licences.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled licence texts are the repo copies', () {
    expect(_read('assets/licenses/ofl-1.1.txt'), _read('assets/fonts/OFL.txt'));
    expect(_read('assets/licenses/cc0-1.0.txt'), _read('library/LICENSE'));
  });

  test('the Apache text is the full licence', () {
    final t = _read('assets/licenses/apache-2.0.txt');
    expect(t, contains('Version 2.0, January 2004'));
    expect(t, contains('4. Redistribution.'));
    expect(t, contains('END OF TERMS AND CONDITIONS'));
    expect(t, contains('APPENDIX: How to apply the Apache License'));
  });

  test('registers one entry per notice with its text', () async {
    registerLicences();
    registerLicences(); // a second call adds nothing
    final entries = await LicenseRegistry.licenses.toList();
    final ours = {
      for (final e in entries)
        if (licencePackages.contains(e.packages.single))
          e.packages.single: e.paragraphs.map((p) => p.text).join('\n'),
    };
    expect(
      entries.where((e) => e.packages.contains('ZXing core')),
      hasLength(1),
    );
    expect(ours.keys, unorderedEquals(licencePackages));
    expect(ours['ZXing core'], contains('Apache License'));
    expect(ours['Inter Tight'], contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(ours['SQLite'], contains('May you do good and not evil.'));
    expect(ours['Grain gear library'], contains('CC0 1.0 Universal'));
  });
}
