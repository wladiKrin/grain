import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../version.dart';

/// A notice Flutter does not collect from the pub packages: the Kotlin side,
/// the font, the vendored C library and the gear library.
typedef _Notice = ({String package, String? header, String asset});

const List<_Notice> _notices = [
  (
    package: 'ZXing core',
    header:
        'ZXing core 3.5.4 (QR code decoding), Copyright ZXing authors. '
        'Licensed under the Apache License, Version 2.0.',
    asset: 'assets/licenses/apache-2.0.txt',
  ),
  (package: 'Inter Tight', header: null, asset: 'assets/licenses/ofl-1.1.txt'),
  (package: 'SQLite', header: null, asset: 'assets/licenses/sqlite.txt'),
  (
    package: 'Grain gear library',
    header:
        'The bundled camera and lens profiles are dedicated to the public '
        'domain under CC0 1.0.',
    asset: 'assets/licenses/cc0-1.0.txt',
  ),
];

/// The package names [registerLicences] adds to the licence page.
List<String> get licencePackages => [for (final n in _notices) n.package];

bool _registered = false;

/// Adds the notices for ZXing core, Inter Tight, SQLite and the gear library
/// to Flutter's [LicenseRegistry], beside the pub packages' own. Safe to call
/// more than once.
void registerLicences([AssetBundle? bundle]) {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    final b = bundle ?? rootBundle;
    for (final n in _notices) {
      final text = await b.loadString(n.asset);
      yield LicenseEntryWithLineBreaks([
        n.package,
      ], n.header == null ? text : '${n.header}\n\n$text');
    }
  });
}

/// The licence page: Grain's own line, then every package's notices.
void showLicences(BuildContext context) => showLicensePage(
  context: context,
  applicationName: 'Grain',
  applicationVersion: appVersion,
  applicationLegalese: 'GPLv3',
);
