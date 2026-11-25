import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:grain/map/tile_loading.dart';
import 'package:http/http.dart' as http;

/// A 2×2 red PNG: told apart from the 1×1 blank flutter_map draws for a
/// load it gave up.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8'
  'oH+WdZbrcAAAAASUVORK5CYII=',
);

/// Tiles not drawn from the server's image: failed, blank or not loaded.
Iterable<TileImage> notLoaded(List<TileImage> tiles) => tiles.where(
  (i) => i.loadError || i.imageInfo == null || i.imageInfo!.image.width != 2,
);

/// Fails each URL's first [failFirst] requests (as [failure] says), then
/// serves [png]; requests wait for [gate] if set, and give up when
/// aborted. Counts requests, and the most at once.
class FakeServer {
  FakeServer({this.failFirst = 0, this.failure = dropped});

  int failFirst;
  http.Response Function() failure;
  Completer<void>? gate;
  final perUrl = <String, int>{};
  final agents = <String?>{};
  int requests = 0, inFlight = 0, mostInFlight = 0, aborted = 0;

  static http.Response dropped() => throw http.ClientException(
    'Connection closed before full header was received',
  );

  late final client = FakeClient((r) async {
    requests++;
    agents.add(r.headers['User-Agent']);
    inFlight++;
    if (inFlight > mostInFlight) mostInFlight = inFlight;
    try {
      if (gate case final g?) {
        final abort = (r as http.Abortable).abortTrigger;
        await Future.any([g.future, ?abort]);
        if (!g.isCompleted) {
          aborted++;
          throw http.RequestAbortedException(r.url);
        }
      }
      final n = perUrl[r.url.toString()] = (perUrl[r.url.toString()] ?? 0) + 1;
      if (n <= failFirst) return failure();
      return http.Response.bytes(
        png,
        200,
        headers: {
          'cache-control': 'max-age=3600',
          'date': HttpDate.format(DateTime.now()),
        },
      );
    } finally {
      inFlight--;
    }
  });

  TileFetcher fetcher({int attempts = 3}) => TileFetcher(
    client: client,
    userAgent: 'Grain/test',
    attempts: attempts,
    backoff: Duration.zero,
  );
}

/// Hands the request itself to [handler] (MockClient hands a copy, which
/// cannot be aborted).
class FakeClient extends http.BaseClient {
  FakeClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest r) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final r = await handler(request);
    return http.StreamedResponse(
      Stream.value(r.bodyBytes),
      r.statusCode,
      headers: r.headers,
      request: request,
    );
  }
}

/// Remembers what is put; serves what it was given.
class FakeCache implements MapCachingProvider {
  final tiles = <String, CachedMapTile>{};
  final puts = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<CachedMapTile?> getTile(String url) async => tiles[url];

  @override
  Future<void> putTile({
    required String url,
    required CachedMapTileMetadata metadata,
    Uint8List? bytes,
  }) async {
    puts.add(url);
    if (bytes != null) tiles[url] = (bytes: bytes, metadata: metadata);
  }
}
