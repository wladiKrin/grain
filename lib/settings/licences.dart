import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../version.dart';

/// A notice Flutter does not collect from the pub packages: the Kotlin side,
/// the fonts, the vendored C library, the gear library, the map engine and
/// the map data (bundled, and the online OpenFreeMap styles').
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
    package: 'MapLibre Native',
    header:
        'MapLibre Native for Android 13.7.1 draws the map (through the '
        'maplibre_gl plugin). BSD 2-Clause License.',
    asset: 'assets/licenses/maplibre-native.txt',
  ),
  (
    package: 'OkHttp',
    header:
        'OkHttp 5 (the map’s HTTP client), Copyright Square, Inc. Licensed '
        'under the Apache License, Version 2.0.',
    asset: 'assets/licenses/apache-2.0.txt',
  ),
  (
    package: 'Noto Sans',
    header:
        'The offline map’s place names are drawn with Noto Sans Regular and '
        'Bold (glyphs from openmaptiles/fonts, cut to the characters used).',
    asset: 'assets/licenses/noto-sans.txt',
  ),
  (
    package: 'Grain gear library',
    header:
        'The bundled camera and lens profiles are dedicated to the public '
        'domain under CC0 1.0.',
    asset: 'assets/licenses/cc0-1.0.txt',
  ),
  (
    package: 'Natural Earth',
    header:
        'The offline map is made with Natural Earth (land, lakes, borders '
        'and places), which is in the public domain.',
    asset: 'assets/licenses/natural-earth.txt',
  ),
  (
    package: 'OpenFreeMap and OpenMapTiles',
    header:
        'The Streets and Minimal map styles: OpenFreeMap styles and vector '
        'tiles in the OpenMapTiles schema (CC-BY 4.0), with OpenStreetMap '
        'data (ODbL).',
    asset: 'assets/licenses/openfreemap.txt',
  ),
];

/// The package names [registerLicences] adds to the licence page.
List<String> get licencePackages => [for (final n in _notices) n.package];

bool _registered = false;

/// Adds the notices for ZXing core, Inter Tight, SQLite, MapLibre Native,
/// OkHttp, Noto Sans, the gear library, Natural Earth and OpenFreeMap to
/// Flutter's [LicenseRegistry], beside the pub packages' own (maplibre_gl
/// among them). Safe to call more than once.
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
