import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// A tile load given up because its tile left the map (pruned while
/// zooming or panning): not a failure, and never drawn.
class TileCancelled implements Exception {
  const TileCancelled(this.uri);

  final Uri uri;

  @override
  String toString() => 'Tile load cancelled: $uri';
}

/// A tile server answered, but not with a tile (or an empty one).
class TileHttpError implements Exception {
  const TileHttpError(this.uri, this.statusCode);

  final Uri uri;
  final int statusCode;

  @override
  String toString() => 'HTTP $statusCode: $uri';
}

/// Whether [error] is a load given up, not a failure to count.
bool isTileCancellation(Object error) =>
    error is TileCancelled || error is http.RequestAbortedException;

/// Fetches tiles and the files a map style needs, the way the tile servers'
/// usage policies ask: one shared client naming Grain, at most
/// [connectionsPerHost] requests to a server at a time (the others wait
/// here, and a wait given up costs no request). A dropped connection, a
/// timeout or a busy server (408, 429, 5xx) is tried again, up to
/// [attempts] times in all, a little later each time.
class TileFetcher {
  TileFetcher({
    http.Client? client,
    required this.userAgent,
    this.connectionsPerHost = 2,
    this.attempts = 3,
    this.timeout = const Duration(seconds: 20),
    this.backoff = const Duration(milliseconds: 700),
  }) : _client = client ?? _ioClient(connectionsPerHost, userAgent),
       _ownsClient = client == null;

  static http.Client _ioClient(int perHost, String userAgent) => IOClient(
    HttpClient()
      ..maxConnectionsPerHost = perHost
      // Servers drop idle connections; reusing one just dropped fails the
      // request, so idle ones are let go early.
      ..idleTimeout = const Duration(seconds: 5)
      ..userAgent = userAgent,
  );

  final http.Client _client;
  final bool _ownsClient;
  final String userAgent;
  final int connectionsPerHost;
  final int attempts;
  final Duration timeout;
  final Duration backoff;

  final _hosts = <String, _Host>{};
  bool _closed = false;

  /// Requests waiting for a connection, over all servers.
  @visibleForTesting
  int get waiting => _hosts.values.fold(0, (n, h) => n + h.waiting.length);

  /// GETs [uri]: the response if 200 (or 304, when [headers] ask whether
  /// a copy is still good). Throws [TileCancelled] once [cancel] completes,
  /// [TileHttpError] for any other status, or the last network error.
  Future<http.Response> get(
    Uri uri, {
    Map<String, String> headers = const {},
    Future<void>? cancel,
  }) async {
    final cancelled = _Cancel(cancel);
    for (var attempt = 1; ; attempt++) {
      if (cancelled.done || _closed) throw TileCancelled(uri);
      await _acquire(uri.host, cancelled, uri);
      Object? error;
      StackTrace? stack;
      try {
        final r = await _send(uri, headers, cancelled);
        if (r.statusCode == HttpStatus.ok ||
            r.statusCode == HttpStatus.notModified) {
          return r;
        }
        error = TileHttpError(uri, r.statusCode);
        if (!_retryable(r.statusCode)) throw error;
      } on TileCancelled {
        rethrow;
      } on TileHttpError {
        rethrow;
      } catch (e, s) {
        error = e;
        stack = s;
      } finally {
        _release(uri.host);
      }
      if (attempt >= attempts) {
        Error.throwWithStackTrace(error, stack ?? StackTrace.current);
      }
      await cancelled.wait(backoff * attempt);
    }
  }

  Future<http.Response> _send(
    Uri uri,
    Map<String, String> headers,
    _Cancel cancelled,
  ) async {
    // Aborted when the tile goes, or when the server takes too long.
    final abort = Completer<void>();
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      if (!abort.isCompleted) abort.complete();
    });
    cancelled.onCancel(() {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final request =
          http.AbortableRequest('GET', uri, abortTrigger: abort.future)
            ..headers['User-Agent'] = userAgent
            ..headers.addAll(headers);
      return await http.Response.fromStream(await _client.send(request));
    } on http.RequestAbortedException {
      if (timedOut) throw TimeoutException('No answer', timeout);
      throw TileCancelled(uri);
    } finally {
      timer.cancel();
    }
  }

  static bool _retryable(int status) =>
      status == 408 || status == 429 || status >= 500;

  Future<void> _acquire(String host, _Cancel cancelled, Uri uri) {
    final h = _hosts.putIfAbsent(host, _Host.new);
    if (h.active < connectionsPerHost) {
      h.active++;
      return Future.value();
    }
    final slot = Completer<void>();
    h.waiting.add(slot);
    cancelled.onCancel(() {
      if (h.waiting.remove(slot)) slot.completeError(TileCancelled(uri));
    });
    return slot.future;
  }

  void _release(String host) {
    final h = _hosts[host]!;
    if (h.waiting.isNotEmpty) {
      // The connection passes to the longest waiting.
      h.waiting.removeFirst().complete();
    } else {
      h.active--;
    }
  }

  /// Gives up every waiting request; the client closes if made here.
  void close() {
    _closed = true;
    for (final h in _hosts.values) {
      while (h.waiting.isNotEmpty) {
        h.waiting.removeFirst().completeError(TileCancelled(Uri()));
      }
    }
    if (_ownsClient) _client.close();
  }
}

class _Host {
  int active = 0;
  final waiting = Queue<Completer<void>>();
}

/// [future] completing as a flag and callbacks.
class _Cancel {
  _Cancel(Future<void>? future) {
    future?.whenComplete(() {
      done = true;
      for (final f in _callbacks) {
        f();
      }
      _callbacks.clear();
    });
  }

  bool done = false;
  final _callbacks = <VoidCallback>[];

  void onCancel(VoidCallback f) => done ? f() : _callbacks.add(f);

  /// Waits [d], or less if cancelled.
  Future<void> wait(Duration d) {
    final c = Completer<void>();
    final t = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    onCancel(() {
      t.cancel();
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }
}

/// The raster tile provider of every online raster style. Unlike
/// flutter_map's own, it never draws a tile it did not get: a load given
/// up when its tile leaves the map just ends (not in a blank tile taken
/// for loaded, nor in an error), each tile's load is its own (a tile that comes
/// back while its old load is being given up does not get that load's
/// blank), errors are tried again ([TileFetcher]) and never cached, and a
/// server's error page is an error, not a tile. Only 200 responses that
/// decode go into [cache].
class GrainTileProvider extends TileProvider {
  GrainTileProvider({
    required this.fetcher,
    this.cache,
    this.ownsFetcher = false,
  }) : super(headers: {'User-Agent': fetcher.userAgent});

  final TileFetcher fetcher;

  /// Tiles on disk; null: none kept.
  final MapCachingProvider? cache;

  /// Whether [dispose] closes [fetcher].
  final bool ownsFetcher;

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      getImageWithCancelLoadingSupport(
        coordinates,
        options,
        Completer<void>().future,
      );

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) => GrainTileImage(
    url: getTileUrl(coordinates, options),
    fetcher: fetcher,
    cache: cache,
    cancel: cancelLoading,
  );

  @override
  void dispose() {
    if (ownsFetcher) fetcher.close();
    super.dispose();
  }
}

/// One tile's image. Equal only to itself, so Flutter's image cache never
/// hands one tile's load to another; once loaded it leaves that cache (the
/// tile holds its image, and the disk cache keeps the bytes).
class GrainTileImage extends ImageProvider<GrainTileImage> {
  GrainTileImage({
    required this.url,
    required this.fetcher,
    required this.cache,
    required this.cancel,
  });

  final String url;
  final TileFetcher fetcher;
  final MapCachingProvider? cache;
  final Future<void> cancel;

  @override
  Future<GrainTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    GrainTileImage key,
    ImageDecoderCallback decode,
  ) {
    void leaveCache() =>
        scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    final codec = Completer<ui.Codec>();
    var gone = false;
    cancel.whenComplete(() => gone = true).ignore();
    _load(decode).then(
      (c) {
        codec.complete(c);
        leaveCache();
      },
      onError: (Object e, StackTrace s) {
        leaveCache();
        // Given up, or failed after its tile left the map: nothing listens
        // (each tile has its own load), so the load just ends, unresolved
        // and unreported.
        if (e is TileCancelled || gone) return;
        codec.completeError(e, s);
      },
    );
    return MultiFrameImageStreamCompleter(
      codec: codec.future,
      scale: 1,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    Future<ui.Codec> decodeBytes(Uint8List b) =>
        ui.ImmutableBuffer.fromUint8List(b).then(decode);
    final uri = Uri.parse(url);
    final cache = this.cache != null && this.cache!.isSupported
        ? this.cache
        : null;
    CachedMapTile? cached;
    if (cache != null) {
      try {
        cached = await cache.getTile(url);
      } on Exception {
        cached = null;
      }
    }
    if (cached != null && !cached.metadata.isStale) {
      try {
        return await decodeBytes(cached.bytes);
      } on Exception {
        cached = null;
      }
    }
    try {
      final r = await fetcher.get(
        uri,
        cancel: cancel,
        headers: {
          HttpHeaders.ifNoneMatchHeader: ?cached?.metadata.etag,
          if (cached?.metadata.lastModified case final at?)
            HttpHeaders.ifModifiedSinceHeader: HttpDate.format(at),
        },
      );
      if (r.statusCode == HttpStatus.notModified) {
        if (cached == null) throw TileHttpError(uri, r.statusCode);
        final codec = await decodeBytes(cached.bytes);
        _put(cache, null, r.headers);
        return codec;
      }
      final bytes = r.bodyBytes;
      if (bytes.isEmpty) throw TileHttpError(uri, r.statusCode);
      final codec = await decodeBytes(bytes);
      _put(cache, bytes, r.headers);
      return codec;
    } on TileCancelled {
      rethrow;
    } catch (_) {
      // Offline with an old copy: the old copy, not nothing.
      if (cached != null) {
        try {
          return await decodeBytes(cached.bytes);
        } on Exception {
          // Fall through to the load's own error.
        }
      }
      rethrow;
    }
  }

  void _put(
    MapCachingProvider? cache,
    Uint8List? bytes,
    Map<String, String> headers,
  ) {
    if (cache == null) return;
    try {
      unawaited(
        cache
            .putTile(
              url: url,
              metadata: CachedMapTileMetadata.fromHttpHeaders(headers),
              bytes: bytes,
            )
            .catchError((Object _) {}),
      );
    } on Object {
      // A server whose headers say nothing usable: the tile is not kept.
    }
  }
}

/// Failed tiles, loaded again when the map next comes to rest: the network
/// may be back, or the server less busy. A tile that left the map in the
/// meantime is not (the tile layer asks for it afresh when it is back).
class TileRetries {
  final _failed = <TileImage>{};

  int get length => _failed.length;

  void failed(TileImage tile) => _failed.add(tile);

  void clear() => _failed.clear();

  /// Loads each failed tile still on the map from [provider] again, as
  /// [layer] would; returns how many.
  int retry(TileProvider provider, TileLayer layer) {
    final tiles = _failed.toList();
    _failed.clear();
    var n = 0;
    for (final t in tiles) {
      if (t.cancelLoading.isCompleted || !t.loadError) continue;
      t.imageProvider = provider.supportsCancelLoading
          ? provider.getImageWithCancelLoadingSupport(
              t.coordinates,
              layer,
              t.cancelLoading.future,
            )
          : provider.getImage(t.coordinates, layer);
      t.load();
      n++;
    }
    return n;
  }
}
