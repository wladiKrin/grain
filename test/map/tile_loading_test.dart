import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/map/tile_loading.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'tile_fixtures.dart';

void main() {
  group('TileFetcher', () {
    test(
      'tries a dropped connection, a busy server and a timeout again',
      () async {
        for (final failure in [
          FakeServer.dropped,
          () => http.Response('busy', 429),
          () => http.Response('down', 503),
        ]) {
          final server = FakeServer(failFirst: 2, failure: failure);
          final r = await server.fetcher().get(
            Uri.parse('https://a.example/1'),
          );
          expect(r.statusCode, 200);
          expect(server.requests, 3);
          expect(server.agents, {'Grain/test'});
        }
        final server = FakeServer(failFirst: 3);
        await expectLater(
          server.fetcher().get(Uri.parse('https://a.example/1')),
          throwsA(isA<http.ClientException>()),
        );
        expect(server.requests, 3);
      },
    );

    test('an error page is an error, not tried again', () async {
      final server = FakeServer(
        failFirst: 1,
        failure: () => http.Response.bytes(png, 403),
      );
      await expectLater(
        server.fetcher().get(Uri.parse('https://a.example/1')),
        throwsA(
          isA<TileHttpError>().having((e) => e.statusCode, 'status', 403),
        ),
      );
      expect(server.requests, 1);
    });

    test('at most two requests to a server at a time; one given up while '
        'waiting is never sent', () async {
      final server = FakeServer()..gate = Completer<void>();
      final fetcher = server.fetcher();
      final cancel = Completer<void>();
      final done = [
        for (var i = 0; i < 4; i++)
          fetcher.get(Uri.parse('https://a.example/$i')),
        fetcher.get(Uri.parse('https://b.example/0')),
      ];
      final given = fetcher.get(
        Uri.parse('https://a.example/given-up'),
        cancel: cancel.future,
      );
      await pumpEventQueue();
      expect(server.inFlight, 3);
      expect(fetcher.waiting, 3);
      cancel.complete();
      await expectLater(given, throwsA(isA<TileCancelled>()));
      expect(fetcher.waiting, 2);
      server.gate!.complete();
      await Future.wait(done);
      expect(server.mostInFlight, 3);
      expect(server.perUrl.keys, isNot(contains(contains('given-up'))));
    });

    test('a request in flight is aborted when given up', () async {
      final server = FakeServer()..gate = Completer<void>();
      final cancel = Completer<void>();
      final r = server.fetcher().get(
        Uri.parse('https://a.example/1'),
        cancel: cancel.future,
      );
      await pumpEventQueue();
      cancel.complete();
      await expectLater(r, throwsA(isA<TileCancelled>()));
      expect(server.aborted, 1);
      expect(isTileCancellation(TileCancelled(Uri())), isTrue);
      expect(isTileCancellation(http.RequestAbortedException()), isTrue);
      expect(isTileCancellation(TileHttpError(Uri(), 503)), isFalse);
    });
  });

  group('GrainTileProvider', () {
    Future<Object?> load(WidgetTester t, ImageProvider p) =>
        t.runAsync<Object?>(() {
          final c = Completer<Object?>();
          p
              .resolve(ImageConfiguration.empty)
              .addListener(
                ImageStreamListener(
                  (info, _) => c.complete(info),
                  onError: (e, _) => c.complete(e),
                ),
              );
          return c.future;
        });

    final layer = TileLayer(urlTemplate: 'https://a.example/{z}/{x}/{y}.png');
    const at = TileCoordinates(1, 2, 3);

    testWidgets('a tile that loads is kept; each tile’s load is its own', (
      t,
    ) async {
      final server = FakeServer(), cache = FakeCache();
      final p = GrainTileProvider(fetcher: server.fetcher(), cache: cache);
      final a = p.getImageWithCancelLoadingSupport(
        at,
        layer,
        Completer<void>().future,
      );
      final b = p.getImageWithCancelLoadingSupport(
        at,
        layer,
        Completer<void>().future,
      );
      expect(a, isNot(b));
      expect(await load(t, a), isA<ImageInfo>());
      expect(cache.puts, ['https://a.example/3/1/2.png']);
      // From the disk cache: no request.
      expect(await load(t, b), isA<ImageInfo>());
      expect(server.requests, 1);
      expect(p.headers['User-Agent'], 'Grain/test');
    });

    testWidgets('errors and error pages are not cached, and fail the tile', (
      t,
    ) async {
      for (final failure in [
        () => http.Response.bytes(png, 403),
        () => http.Response('<html>blocked</html>', 200),
        () => http.Response('', 200),
        FakeServer.dropped,
      ]) {
        final server = FakeServer(failFirst: 9, failure: failure);
        final cache = FakeCache();
        final p = GrainTileProvider(
          fetcher: server.fetcher(attempts: 1),
          cache: cache,
        );
        final e = await load(t, p.getImage(at, layer));
        expect(e, isNot(isA<ImageInfo>()));
        expect(e, isNot(isA<TileCancelled>()));
        expect(cache.puts, isEmpty);
      }
    });

    testWidgets('offline, an old copy shows rather than nothing', (t) async {
      final cache = FakeCache();
      cache.tiles['https://a.example/3/1/2.png'] = (
        bytes: png,
        metadata: CachedMapTileMetadata(
          staleAt: DateTime(2000),
          lastModified: null,
          etag: null,
        ),
      );
      final server = FakeServer(failFirst: 9);
      final p = GrainTileProvider(fetcher: server.fetcher(), cache: cache);
      expect(await load(t, p.getImage(at, layer)), isA<ImageInfo>());
      expect(server.requests, 3);
    });

    testWidgets('a tile given up just ends: no blank tile, no error', (
      t,
    ) async {
      final server = FakeServer()..gate = Completer<void>();
      final p = GrainTileProvider(fetcher: server.fetcher());
      final cancel = Completer<void>();
      final image = p.getImageWithCancelLoadingSupport(
        at,
        layer,
        cancel.future,
      );
      Object? result;
      image
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (info, _) => result = info,
              onError: (e, _) => result = e,
            ),
          );
      await t.runAsync(pumpEventQueue);
      cancel.complete();
      await t.runAsync(pumpEventQueue);
      expect(server.aborted, 1);
      expect(result, isNull);
      expect(t.takeException(), isNull);
      expect(PaintingBinding.instance.imageCache.containsKey(image), isFalse);
    });
  });

  group('on a map', () {
    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 6; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump(const Duration(milliseconds: 300));
      }
    }

    /// Each tile on the map, and whether it loaded.
    List<TileImage> shown(WidgetTester t) => [
      for (final e
          in find
              .byWidgetPredicate((w) => w.runtimeType.toString() == 'Tile')
              .evaluate())
        (e.widget as dynamic).tileImage as TileImage,
    ];

    Future<MapController> pumpMap(
      WidgetTester t,
      TileProvider provider, {
      ErrorTileCallBack? onError,
      Stream<void>? reset,
    }) async {
      t.view.physicalSize = const Size(800, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final map = MapController();
      await t.pumpWidget(
        MaterialApp(
          home: FlutterMap(
            mapController: map,
            options: const MapOptions(
              initialCenter: LatLng(48.137, 11.575),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://a.example/{z}/{x}/{y}.png',
                tileProvider: provider,
                panBuffer: 0,
                tileDisplay: const TileDisplay.instantaneous(),
                evictErrorTileStrategy:
                    EvictErrorTileStrategy.notVisibleRespectMargin,
                errorTileCallback: onError,
              ),
            ],
          ),
        ),
      );
      await settle(t);
      return map;
    }

    testWidgets('tiles whose connection drops at first all end up loaded', (
      t,
    ) async {
      final server = FakeServer(failFirst: 2);
      final errors = <Object>[];
      await pumpMap(
        t,
        GrainTileProvider(fetcher: server.fetcher()),
        onError: (_, e, _) => errors.add(e),
      );
      final tiles = shown(t);
      expect(tiles, isNotEmpty);
      expect(notLoaded(tiles), isEmpty);
      expect(errors, isEmpty);
      expect(server.requests, 3 * tiles.length);
    });

    testWidgets('zooming in and out while tiles load: the loads given up '
        'are no errors, and every cell ends up loaded', (t) async {
      final server = FakeServer()..gate = Completer<void>();
      final errors = <Object>[];
      final map = await pumpMap(
        t,
        GrainTileProvider(fetcher: server.fetcher()),
        onError: (_, e, _) => errors.add(e),
      );
      for (final z in [14.0, 13.0, 14.0, 15.0, 14.0]) {
        map.move(const LatLng(48.137, 11.575), z);
        await t.pump();
        await t.runAsync(pumpEventQueue);
      }
      server.gate!.complete();
      server.gate = null;
      await settle(t);
      final tiles = shown(t);
      expect(tiles, isNotEmpty);
      expect(notLoaded(tiles), isEmpty);
      expect(errors, isEmpty);
      expect(server.aborted, greaterThan(0));
    });

    testWidgets('failed tiles load on the next try', (t) async {
      final server = FakeServer(failFirst: 1);
      final provider = GrainTileProvider(fetcher: server.fetcher(attempts: 1));
      final retries = TileRetries();
      await pumpMap(t, provider, onError: (tile, _, _) => retries.failed(tile));
      final failed = shown(t).where((i) => i.loadError).length;
      expect(failed, greaterThan(0));
      expect(retries.length, failed);
      final layer = t.widget<TileLayer>(find.byType(TileLayer));
      expect(retries.retry(provider, layer), failed);
      await settle(t);
      expect(notLoaded(shown(t)), isEmpty);
      expect(retries.length, 0);
    });
  });
}
