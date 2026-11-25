import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    show Logger, SpriteIndexReader, ThemeReader;

import 'tile_loading.dart';

/// The OpenFreeMap styles Grain draws (https://openfreemap.org: free, no
/// key, OpenStreetMap data in the OpenMapTiles schema).
enum OpenFreeMapStyle {
  /// Streets, the Google-like one.
  liberty,

  /// Minimal in the light palette.
  positron,

  /// Minimal in the dark palette.
  dark;

  Uri get uri => Uri.parse('https://tiles.openfreemap.org/styles/$name');
}

/// What OpenFreeMap asks a client other than MapLibre to show.
const openFreeMapAttribution =
    'OpenFreeMap © OpenMapTiles Data from OpenStreetMap';

/// Where the vector styles come from: the style, its sprites and its tile
/// providers, and the folder their tiles are kept in.
abstract interface class VectorStyleSource {
  /// The style ready to draw. Fails if it cannot be had (offline, say, and
  /// never loaded before).
  Future<Style> load(OpenFreeMapStyle style);

  /// The folder the vector layer keeps tiles in (its own, size-capped).
  Future<Directory> cacheFolder();
}

/// Bumped when Grain changes how it reads a style, so tiles drawn the old
/// way are not shown again.
const _themeVersion = 'grain-1';

/// [json], an OpenFreeMap style, as Grain draws it: its vector source only
/// (the shaded-relief raster under the low zooms is left out; the offline
/// basemap is under it anyway), with an id of its own so each style's
/// drawn tiles are kept apart.
Map<String, dynamic> prepareStyle(
  OpenFreeMapStyle style,
  Map<String, dynamic> json,
) {
  final sources = <String, dynamic>{
    for (final MapEntry(:key, :value)
        in (json['sources'] as Map? ?? const {}).entries)
      if (value is Map && value['type'] == 'vector') key as String: value,
  };
  return {
    ...json,
    'id': 'openfreemap-${style.name}',
    'metadata': {
      if (json['metadata'] case final Map<String, dynamic> m) ...m,
      'version': _themeVersion,
    },
    'sources': sources,
    'layers': [
      for (final layer in json['layers'] as List? ?? const [])
        if (layer is Map &&
            (layer['source'] == null || sources.containsKey(layer['source'])))
          layer,
    ],
  };
}

/// Reads [json] (an OpenFreeMap style) into a [Style]. [readJson] and
/// [readBytes] fetch what it points to: each vector source's TileJSON and
/// the sprites (high density first); [tiles] makes a source's provider.
Future<Style> readStyle(
  OpenFreeMapStyle style,
  Map<String, dynamic> json, {
  required Future<Object?> Function(Uri uri) readJson,
  required Future<Uint8List> Function(Uri uri) readBytes,
  required VectorTileProvider Function(String urlTemplate, int min, int max)
  tiles,
}) async {
  final prepared = prepareStyle(style, json);
  final providers = <String, VectorTileProvider>{};
  for (final MapEntry(:key, :value)
      in (prepared['sources'] as Map<String, dynamic>).entries) {
    var source = value as Map;
    if (source['url'] case final String url) {
      final tileJson = await readJson(Uri.parse(url));
      if (tileJson is! Map) throw FormatException('Not a TileJSON: $url');
      source = tileJson;
    }
    final urls = source['tiles'];
    if (urls is! List || urls.isEmpty) continue;
    providers[key] = tiles(
      urls.first as String,
      (source['minzoom'] as num?)?.toInt() ?? 0,
      (source['maxzoom'] as num?)?.toInt() ?? 14,
    );
  }
  if (providers.isEmpty) {
    throw FormatException('No vector tiles in ${style.uri}');
  }
  SpriteStyle? sprites;
  if (prepared['sprite'] case final String base when base.isNotEmpty) {
    for (final suffix in const ['@2x', '']) {
      try {
        final index = await readJson(Uri.parse('$base$suffix.json'));
        final atlas = Uri.parse('$base$suffix.png');
        sprites = SpriteStyle(
          atlasProvider: () => readBytes(atlas),
          index: SpriteIndexReader(logger: const Logger.noop())
              .read(index as Map<String, dynamic>),
        );
        break;
      } on Object {
        // Try the next density; without sprites the map has no icons.
      }
    }
  }
  return Style(
    name: style.name,
    theme: ThemeReader(logger: const Logger.noop()).read(prepared),
    providers: TileProviders(providers),
    sprites: sprites,
  );
}

/// Vector tiles from a server, fetched by Grain's [TileFetcher] (one
/// client, a few connections, retries).
class FetchedVectorTiles extends VectorTileProvider {
  FetchedVectorTiles({
    required this.fetcher,
    required this.urlTemplate,
    required this.minimumZoom,
    required this.maximumZoom,
  });

  final TileFetcher fetcher;
  final String urlTemplate;

  @override
  final int minimumZoom;

  @override
  final int maximumZoom;

  @override
  TileOffset get tileOffset => TileOffset.DEFAULT;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    final uri = Uri.parse(
      urlTemplate
          .replaceAll('{z}', '${tile.z}')
          .replaceAll('{x}', '${tile.x}')
          .replaceAll('{y}', '${tile.y}'),
    );
    try {
      final r = await fetcher.get(uri);
      return r.bodyBytes;
    } on TileHttpError catch (e) {
      throw ProviderException(
        message: e.toString(),
        statusCode: e.statusCode,
        retryable: Retryable.none,
      );
    } on ProviderException {
      rethrow;
    } on Exception catch (e) {
      throw ProviderException(message: '$e', retryable: Retryable.retry);
    }
  }
}

/// [inner], telling [onLoaded] and [onFailed] how each tile went (for the
/// note shown when the online map does not load). A tile the server has
/// not got (404, as over the sea at some zooms) is no failure.
class ReportingVectorTiles extends VectorTileProvider {
  ReportingVectorTiles(
    this.inner, {
    required this.onLoaded,
    required this.onFailed,
  });

  final VectorTileProvider inner;
  final VoidCallback onLoaded;
  final void Function(Object error) onFailed;

  @override
  int get maximumZoom => inner.maximumZoom;

  @override
  int get minimumZoom => inner.minimumZoom;

  @override
  TileOffset get tileOffset => inner.tileOffset;

  @override
  TileProviderType get type => inner.type;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    try {
      final bytes = await inner.provide(tile);
      onLoaded();
      return bytes;
    } on ProviderException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 204) onFailed(e);
      rethrow;
    } on Object catch (e) {
      if (!isTileCancellation(e)) onFailed(e);
      rethrow;
    }
  }
}

/// [style] with each of its tile providers reporting to [onLoaded] and
/// [onFailed].
Style reportingStyle(
  Style style, {
  required VoidCallback onLoaded,
  required void Function(Object error) onFailed,
}) => Style(
  name: style.name,
  theme: style.theme,
  sprites: style.sprites,
  providers: TileProviders({
    for (final MapEntry(:key, :value)
        in style.providers.tileProviderBySource.entries)
      key: ReportingVectorTiles(value, onLoaded: onLoaded, onFailed: onFailed),
  }),
);

/// The OpenFreeMap styles, read from tiles.openfreemap.org and kept in
/// [cacheRoot]: the style and its TileJSON for a day (the tiles' address
/// changes with each weekly build), the sprites for a month. Offline, an
/// older copy is used rather than none. Each style is read once per run.
class OpenFreeMap implements VectorStyleSource {
  OpenFreeMap({
    required this.fetcher,
    required this.cacheRoot,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TileFetcher fetcher;

  /// The app's cache directory; the files go in folders of their own.
  final Future<Directory> Function() cacheRoot;
  final DateTime Function() _clock;

  static const styleAge = Duration(days: 1);
  static const spriteAge = Duration(days: 30);

  final _styles = <OpenFreeMapStyle, Future<Style>>{};

  @override
  Future<Style> load(OpenFreeMapStyle style) =>
      _styles[style] ??= _load(style).catchError((Object e, StackTrace s) {
        // Read again next time, the network may be back.
        _styles.remove(style);
        Error.throwWithStackTrace(e, s);
      });

  Future<Style> _load(OpenFreeMapStyle style) async {
    final json = await _json(style.uri, styleAge);
    if (json is! Map<String, dynamic>) {
      throw FormatException('Not a style: ${style.uri}');
    }
    return readStyle(
      style,
      json,
      readJson: (uri) =>
          _json(uri, uri.path.contains('/sprites/') ? spriteAge : styleAge),
      readBytes: (uri) => _bytes(uri, spriteAge),
      tiles: (url, min, max) => FetchedVectorTiles(
        fetcher: fetcher,
        urlTemplate: url,
        minimumZoom: min,
        maximumZoom: max,
      ),
    );
  }

  @override
  Future<Directory> cacheFolder() async {
    final d = Directory('${(await cacheRoot()).path}/vector_tiles');
    await d.create(recursive: true);
    return d;
  }

  Future<Object?> _json(Uri uri, Duration age) async =>
      compute(_decodeJson, await _bytes(uri, age));

  /// [uri]'s bytes: the copy on disk while younger than [age], otherwise
  /// fetched (and kept); if that fails, the copy on disk however old.
  Future<Uint8List> _bytes(Uri uri, Duration age) async {
    final dir = Directory('${(await cacheRoot()).path}/openfreemap');
    final file = File('${dir.path}/${_fileName(uri)}');
    FileStat? stat;
    try {
      stat = await file.stat();
      if (stat.type == FileSystemEntityType.notFound) stat = null;
    } on FileSystemException {
      stat = null;
    }
    if (stat != null && _clock().difference(stat.modified) < age) {
      return file.readAsBytes();
    }
    try {
      final r = await fetcher.get(uri);
      final bytes = r.bodyBytes;
      try {
        await dir.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
      } on FileSystemException {
        // Not kept: fetched again next time.
      }
      return bytes;
    } on Object {
      if (stat != null) return file.readAsBytes();
      rethrow;
    }
  }

  /// A file name for [uri]: its path, made safe, and a hash of the whole.
  static String _fileName(Uri uri) {
    var h = 0x811c9dc5;
    for (final c in utf8.encode(uri.toString())) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    final tail = uri.pathSegments.isEmpty ? 'root' : uri.pathSegments.last;
    final safe = tail.replaceAll(RegExp(r'[^A-Za-z0-9@._-]'), '_');
    return '${h.toRadixString(16)}-$safe';
  }
}

Object? _decodeJson(Uint8List bytes) => jsonDecode(utf8.decode(bytes));
