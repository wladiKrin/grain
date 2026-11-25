import 'dart:io';
import 'dart:typed_data';

import 'package:grain/map/vector_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile/raw/raw_vector_tile.dart' as raw;

/// Zigzag-encodes a tile coordinate step.
int _zz(int n) => (n << 1) ^ (n >> 31);

/// A vector tile in the OpenMapTiles schema: water over the whole tile and
/// a primary road across it. Built here, so no test fetches one.
Uint8List fixtureTile() {
  const e = 4096;
  final square = [
    9, _zz(0), _zz(0), // MoveTo
    26, _zz(e), _zz(0), _zz(0), _zz(e), _zz(-e), _zz(0), // LineTo ×3
    15, // ClosePath
  ];
  final road = [9, _zz(0), _zz(e ~/ 2), 10, _zz(e), _zz(0)];
  final tile = raw.createVectorTile(
    layers: [
      raw.createVectorTileLayer(
        name: 'water',
        extent: e,
        version: 2,
        keys: ['class'],
        values: [raw.createVectorTileValue(stringValue: 'lake')],
        features: [
          raw.createVectorTileFeature(
            type: raw.VectorTile_GeomType.POLYGON,
            tags: [0, 0],
            geometry: square,
          ),
        ],
      ),
      raw.createVectorTileLayer(
        name: 'transportation',
        extent: e,
        version: 2,
        keys: ['class'],
        values: [raw.createVectorTileValue(stringValue: 'primary')],
        features: [
          raw.createVectorTileFeature(
            type: raw.VectorTile_GeomType.LINESTRING,
            tags: [0, 0],
            geometry: road,
          ),
        ],
      ),
    ],
  );
  return tile.writeToBuffer();
}

/// A style shaped like OpenFreeMap's: a shaded-relief raster source and
/// the OpenMapTiles vector source (by TileJSON), sprites, and a
/// background, raster, water and road layer.
Map<String, dynamic> fixtureStyle() => {
  'version': 8,
  'sources': {
    'ne2_shaded': {
      'type': 'raster',
      'maxzoom': 6,
      'tileSize': 256,
      'tiles': ['https://tiles.example/ne2sr/{z}/{x}/{y}.png'],
    },
    'openmaptiles': {'type': 'vector', 'url': 'https://tiles.example/planet'},
  },
  'sprite': 'https://tiles.example/sprites/ofm',
  'glyphs': 'https://tiles.example/fonts/{fontstack}/{range}.pbf',
  'layers': [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#f8f4f0'},
    },
    {
      'id': 'natural_earth',
      'type': 'raster',
      'source': 'ne2_shaded',
      'maxzoom': 6,
    },
    {
      'id': 'water',
      'type': 'fill',
      'source': 'openmaptiles',
      'source-layer': 'water',
      'paint': {'fill-color': 'rgb(158,189,255)'},
    },
    {
      'id': 'road_primary',
      'type': 'line',
      'source': 'openmaptiles',
      'source-layer': 'transportation',
      'filter': ['==', 'class', 'primary'],
      'paint': {'line-color': '#fea', 'line-width': 4},
    },
  ],
};

/// The TileJSON [fixtureStyle]'s vector source points to.
const fixtureTileJson = {
  'tilejson': '3.0.0',
  'tiles': ['https://tiles.example/planet/20261122/{z}/{x}/{y}.pbf'],
  'minzoom': 0,
  'maxzoom': 14,
};

/// A sprite index with one icon.
const fixtureSprites = {
  'dot': {'x': 0, 'y': 0, 'width': 2, 'height': 2, 'pixelRatio': 2},
};

/// Serves [fixtureTile] for every tile, counting them; with [fail], each
/// fails as a network error would.
class FakeVectorTiles extends VectorTileProvider {
  FakeVectorTiles({this.maximumZoom = 14});

  final _tile = fixtureTile();
  int requests = 0;
  bool fail = false;

  @override
  final int maximumZoom;

  @override
  int get minimumZoom => 0;

  @override
  TileOffset get tileOffset => TileOffset.DEFAULT;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    requests++;
    if (fail) {
      throw ProviderException(
        message: 'Network is unreachable',
        retryable: Retryable.retry,
      );
    }
    return _tile;
  }
}

/// The vector styles from fixtures: each style is [fixtureStyle] read
/// with [tiles]; with [fail], no style can be read.
class FakeVectorStyles implements VectorStyleSource {
  FakeVectorStyles(this.tiles);

  final FakeVectorTiles tiles;
  bool fail = false;
  final loaded = <OpenFreeMapStyle>[];
  Directory? _dir;

  @override
  Future<Style> load(OpenFreeMapStyle style) async {
    if (fail) throw const SocketException('Network is unreachable');
    loaded.add(style);
    return readStyle(
      style,
      fixtureStyle(),
      readJson: (uri) async => uri.path.endsWith('/planet')
          ? fixtureTileJson
          : throw const SocketException('no sprites in tests'),
      readBytes: (uri) async => throw const SocketException('none'),
      tiles: (url, min, max) => tiles,
    );
  }

  @override
  Future<Directory> cacheFolder() async =>
      _dir ??= Directory.systemTemp.createTempSync('grain-vector-test');
}
