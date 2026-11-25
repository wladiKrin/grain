import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/map/tile_loading.dart';
import 'package:grain/map/vector_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import 'vector_fixtures.dart';

void main() {
  test('the styles are OpenFreeMap’s Liberty, Positron and Dark', () {
    expect(
      OpenFreeMapStyle.liberty.uri.toString(),
      'https://tiles.openfreemap.org/styles/liberty',
    );
    expect(
      OpenFreeMapStyle.positron.uri.toString(),
      'https://tiles.openfreemap.org/styles/positron',
    );
    expect(
      OpenFreeMapStyle.dark.uri.toString(),
      'https://tiles.openfreemap.org/styles/dark',
    );
    expect(
      openFreeMapAttribution,
      'OpenFreeMap © OpenMapTiles Data from OpenStreetMap',
    );
  });

  test('a style keeps its vector source and layers only, with an id of '
      'its own', () {
    final p = prepareStyle(OpenFreeMapStyle.liberty, fixtureStyle());
    expect((p['sources'] as Map).keys, ['openmaptiles']);
    expect(
      [for (final l in p['layers'] as List) l['id']],
      ['background', 'water', 'road_primary'],
    );
    expect(p['id'], 'openfreemap-liberty');
    expect(
      prepareStyle(OpenFreeMapStyle.dark, fixtureStyle())['id'],
      'openfreemap-dark',
    );
    expect((p['metadata'] as Map)['version'], isNotEmpty);
  });

  test('reading a style follows its TileJSON and takes the sharp sprites, '
      'or the plain ones', () async {
    final asked = <String>[];
    final made = <(String, int, int)>[];
    Future<Object?> readJson(Uri uri) async {
      asked.add(uri.toString());
      if (uri.path.endsWith('/planet')) return fixtureTileJson;
      if (uri.path.endsWith('@2x.json')) throw const SocketException('404');
      return fixtureSprites;
    }

    final style = await readStyle(
      OpenFreeMapStyle.positron,
      fixtureStyle(),
      readJson: readJson,
      readBytes: (_) async => Uint8List(0),
      tiles: (url, min, max) {
        made.add((url, min, max));
        return FakeVectorTiles();
      },
    );
    expect(made, [
      ('https://tiles.example/planet/20261122/{z}/{x}/{y}.pbf', 0, 14),
    ]);
    expect(asked, [
      'https://tiles.example/planet',
      'https://tiles.example/sprites/ofm@2x.json',
      'https://tiles.example/sprites/ofm.json',
    ]);
    expect(style.name, 'positron');
    expect(style.theme.id, 'openfreemap-positron');
    expect(style.theme.tileSources, {'openmaptiles'});
    expect(style.providers.tileProviderBySource.keys, ['openmaptiles']);
    expect(style.sprites, isNotNull);

    // No vector source: not a style Grain can draw.
    final bare = fixtureStyle()..['sources'] = {};
    expect(
      readStyle(
        OpenFreeMapStyle.liberty,
        bare,
        readJson: readJson,
        readBytes: (_) async => Uint8List(0),
        tiles: (_, _, _) => FakeVectorTiles(),
      ),
      throwsFormatException,
    );
  });

  group('OpenFreeMap', () {
    late Directory dir;
    late DateTime now;
    late List<String> requests;
    late bool offline;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('grain-ofm');
      now = DateTime.now();
      requests = [];
      offline = false;
    });
    tearDown(() => dir.deleteSync(recursive: true));

    OpenFreeMap make() => OpenFreeMap(
      fetcher: TileFetcher(
        userAgent: 'Grain/test',
        backoff: Duration.zero,
        client: MockClient((r) async {
          requests.add('${r.url} ${r.headers['User-Agent']}');
          if (offline) throw http.ClientException('Network is unreachable');
          final body = switch (r.url.path) {
            '/styles/liberty' => fixtureStyle(),
            '/planet' => fixtureTileJson,
            final p when p.endsWith('.json') => fixtureSprites,
            _ => null,
          };
          return body == null
              ? http.Response('', 404)
              : http.Response(jsonEncode(body), 200);
        }),
      ),
      cacheRoot: () async => dir,
      clock: () => now,
    );

    test('reads the style once per run, sends the Grain User-Agent and '
        'keeps the files', () async {
      final ofm = make();
      final a = await ofm.load(OpenFreeMapStyle.liberty);
      final b = await ofm.load(OpenFreeMapStyle.liberty);
      expect(identical(a, b), isTrue);
      expect(requests, [
        'https://tiles.openfreemap.org/styles/liberty Grain/test',
        'https://tiles.example/planet Grain/test',
        'https://tiles.example/sprites/ofm@2x.json Grain/test',
      ]);
      expect(Directory('${dir.path}/openfreemap').listSync(), hasLength(3));
      expect((await ofm.cacheFolder()).path, '${dir.path}/vector_tiles');
    });

    test('a new run takes the kept files while young, fetches them again '
        'when old, and offline uses old ones rather than none', () async {
      await make().load(OpenFreeMapStyle.liberty);
      requests.clear();
      await make().load(OpenFreeMapStyle.liberty);
      expect(requests, isEmpty);

      now = now.add(OpenFreeMap.styleAge + const Duration(hours: 1));
      await make().load(OpenFreeMapStyle.liberty);
      // Style and TileJSON again; the sprites keep for a month.
      expect(requests, hasLength(2));

      requests.clear();
      now = now.add(OpenFreeMap.spriteAge * 2);
      offline = true;
      final style = await make().load(OpenFreeMapStyle.liberty);
      expect(style.theme.id, 'openfreemap-liberty');
      expect(requests, isNotEmpty);
    });

    test(
      'a style that cannot be read fails, and is read again next time',
      () async {
        offline = true;
        final ofm = make();
        await expectLater(
          ofm.load(OpenFreeMapStyle.liberty),
          throwsA(isA<http.ClientException>()),
        );
        offline = false;
        final style = await ofm.load(OpenFreeMapStyle.liberty);
        expect(style.theme.id, 'openfreemap-liberty');
      },
    );
  });

  test('fetched vector tiles: a missing tile is a 404, a dropped '
      'connection is tried again', () async {
    var calls = 0;
    final tiles = FetchedVectorTiles(
      fetcher: TileFetcher(
        userAgent: 'Grain/test',
        backoff: Duration.zero,
        client: MockClient((r) async {
          calls++;
          if (r.url.path == '/1/0/0.pbf') return http.Response('', 404);
          if (calls == 1) {
            throw http.ClientException(
              'Connection closed before full header was received',
            );
          }
          return http.Response.bytes(fixtureTile(), 200);
        }),
      ),
      urlTemplate: 'https://tiles.example/{z}/{x}/{y}.pbf',
      minimumZoom: 0,
      maximumZoom: 14,
    );
    expect(await tiles.provide(TileIdentity(2, 1, 1)), fixtureTile());
    expect(calls, 2);
    await expectLater(
      tiles.provide(TileIdentity(1, 0, 0)),
      throwsA(
        isA<ProviderException>().having((e) => e.statusCode, 'status', 404),
      ),
    );
  });

  test('reporting tiles count loads and failures, not missing tiles', () async {
    final inner = FakeVectorTiles();
    var loaded = 0;
    final failed = <Object>[];
    final r = ReportingVectorTiles(
      inner,
      onLoaded: () => loaded++,
      onFailed: failed.add,
    );
    await r.provide(TileIdentity(1, 0, 0));
    expect(loaded, 1);
    inner.fail = true;
    await expectLater(r.provide(TileIdentity(1, 0, 0)), throwsException);
    expect(failed, hasLength(1));

    final missing = ReportingVectorTiles(
      _Missing(),
      onLoaded: () => loaded++,
      onFailed: failed.add,
    );
    await expectLater(missing.provide(TileIdentity(1, 0, 0)), throwsException);
    expect(failed, hasLength(1));
  });

  testWidgets('a vector layer draws fake tiles and pans and zooms without '
      'an exception', (t) async {
    final tiles = FakeVectorTiles();
    final styles = FakeVectorStyles(tiles);
    final style = (await t.runAsync(
      () => styles.load(OpenFreeMapStyle.liberty),
    ))!;
    final folder = (await t.runAsync(styles.cacheFolder))!;
    t.view.physicalSize = const Size(800, 1200);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final map = MapController();
    await t.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          mapController: map,
          options: const MapOptions(
            initialCenter: LatLng(48.137, 11.575),
            initialZoom: 12,
          ),
          children: [
            VectorTileLayer(
              theme: style.theme,
              sprites: style.sprites,
              tileProviders: style.providers,
              layerMode: VectorTileLayerMode.raster,
              maximumZoom: 19,
              cacheFolder: (() async => folder) as dynamic,
            ),
          ],
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(tiles.requests, greaterThan(0));
    // Drawn: the tiles show as images.
    expect(find.byType(RawImage), findsWidgets);
    final before = tiles.requests;
    await t.drag(find.byType(FlutterMap), const Offset(-300, 200));
    await settle();
    map.move(const LatLng(48.2, 11.7), 15.5);
    await settle();
    await t.drag(find.byType(FlutterMap), const Offset(250, -250));
    await settle();
    expect(tiles.requests, greaterThan(before));
    expect(t.takeException(), isNull);
    // The layer trims its caches a few seconds in.
    await t.pump(const Duration(seconds: 4));
    await t.pumpWidget(const SizedBox());
    await settle();
  });
}

class _Missing extends FakeVectorTiles {
  @override
  Future<Uint8List> provide(TileIdentity tile) async => throw ProviderException(
    message: 'none',
    statusCode: 404,
    retryable: Retryable.none,
  );
}
