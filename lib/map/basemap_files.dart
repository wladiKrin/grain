import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'basemap.dart';
import 'basemap_geojson.dart';
import 'map_styles.dart';

/// The bundled basemap (see `tool/basemap/`).
const basemapAsset = 'assets/map/basemap.bin';

/// Bumped when [BasemapGeoJson] writes something else: the files are then
/// written again.
const basemapGeoJsonVersion = 1;

Future<OfflineSources>? _bundled;

/// The offline basemap as GeoJSON files MapLibre reads: written once, off
/// the UI thread, from the bundled `basemap.bin` into the app's cache
/// directory, and read from there after (a new basemap or conversion gets
/// files of its own, the old ones are deleted). From the app's own bundle
/// this is done once per run, on first opening the map.
Future<OfflineSources> loadOfflineSources({
  AssetBundle? bundle,
  Future<Directory> Function()? cacheRoot,
}) {
  Future<OfflineSources> load(
    AssetBundle b,
    Future<Directory> Function() root,
  ) async {
    final data = await b.load(basemapAsset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final dir = Directory('${(await root()).path}/map');
    return Isolate.run(() => writeBasemapFiles(bytes, dir));
  }

  if (bundle != null || cacheRoot != null) {
    return load(
      bundle ?? rootBundle,
      cacheRoot ?? getApplicationCacheDirectory,
    );
  }
  return _bundled ??= load(rootBundle, getApplicationCacheDirectory).catchError(
    (Object e) {
      _bundled = null;
      throw e;
    },
  );
}

/// The GeoJSON of the basemap [bytes] in [parent]: kept files if they are
/// all there, otherwise written (a list of them last, so a write cut short
/// is done again).
OfflineSources writeBasemapFiles(Uint8List bytes, Directory parent) {
  final key = '$basemapGeoJsonVersion-${_fnv(bytes).toRadixString(16)}';
  final dir = Directory('${parent.path}/basemap-$key');
  final manifest = File('${dir.path}/manifest.json');
  OfflineSources sources(List<int> zooms) => OfflineSources(
    data: {
      for (final n in BasemapGeoJson.names)
        n: Uri.file('${dir.path}/$n.geojson').toString(),
    },
    placeZooms: zooms,
  );

  if (manifest.existsSync()) {
    try {
      final zooms = (jsonDecode(manifest.readAsStringSync()) as List)
          .cast<int>();
      final all = BasemapGeoJson.names.every(
        (n) => File('${dir.path}/$n.geojson').existsSync(),
      );
      if (all) return sources(zooms);
    } on FormatException {
      // Written again below.
    }
  }
  final geo = BasemapGeoJson.of(Basemap.decode(bytes));
  dir.createSync(recursive: true);
  for (final e in geo.layers.entries) {
    final tmp = File('${dir.path}/${e.key}.geojson.tmp')
      ..writeAsStringSync(e.value, flush: true);
    tmp.renameSync('${dir.path}/${e.key}.geojson');
  }
  manifest.writeAsStringSync(jsonEncode(geo.placeZooms), flush: true);
  for (final old in parent.listSync()) {
    if (old is Directory &&
        old.path != dir.path &&
        old.uri.pathSegments.reversed
            .firstWhere((s) => s.isNotEmpty)
            .startsWith('basemap-')) {
      try {
        old.deleteSync(recursive: true);
      } on FileSystemException {
        // Left for the next time.
      }
    }
  }
  return sources(geo.placeZooms);
}

/// FNV-1a, 32 bits: which basemap the files are of.
int _fnv(Uint8List bytes) {
  var h = 0x811c9dc5;
  for (final b in bytes) {
    h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}
