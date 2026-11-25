import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/map/basemap.dart';
import 'package:grain/map/map_layers.dart';
import 'package:grain/map/map_screen.dart';
import 'package:grain/map/map_style_sheet.dart';
import 'package:grain/map/tile_loading.dart';
import 'package:grain/map/vector_map.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/ui/frame_editor.dart';
import 'package:grain/rolls/ui/reading_screen.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/theme.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart'
    show VectorTileLayer, VectorTileLayerMode;

import '../support/fake_location.dart';
import '../support/gear_fixtures.dart';
import '../support/rolls_fixtures.dart';
import 'tile_fixtures.dart';
import 'vector_fixtures.dart';

/// A 1×1 transparent PNG.
final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// Serves tiles from memory and counts them: the tests never go online.
/// With [fail], or for the first [failFirst], a tile fails to load, as
/// with no network.
class _FakeTiles extends TileProvider {
  int requests = 0;
  bool fail = false;
  int failFirst = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requests++;
    if (fail || requests <= failFirst) return _FailingImage(requests);
    return MemoryImage(_tinyPng);
  }
}

/// A tile that never loads (each request its own, as nothing is cached).
class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage(this.id);

  final int id;

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(const SocketException('Network is unreachable')),
  );

  @override
  bool operator ==(Object other) => other is _FailingImage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

const _munich = GeoFix(latitude: 48.137, longitude: 11.575);
const _berlin = GeoFix(latitude: 52.52, longitude: 13.405);

const _tinyMap = Basemap(
  land: [
    MapPolygon([LatLng(40, 0), LatLng(60, 0), LatLng(60, 20), LatLng(40, 20)]),
  ],
  lakes: [
    MapPolygon([LatLng(47.5, 9), LatLng(47.7, 9.5), LatLng(47.4, 9.6)]),
  ],
  borders: [
    [LatLng(47.6, 7.6), LatLng(47.5, 9.6)],
  ],
  places: [Place(name: 'Munich', position: LatLng(48.14, 11.58), minZoom: 1)],
);

void main() {
  late Settings settings;
  late FakeLocation location;
  late RollController rolls;
  late GearController gear;
  late _FakeTiles tiles;
  late FakeVectorTiles vectorTiles;
  late FakeVectorStyles vectors;
  final a1 = libBody('canon-a1');

  setUp(() async {
    settings = Settings.inMemory();
    await settings.setLocation(true);
    await settings.setSnapshots(false);
    location = FakeLocation(_munich);
    gear = GearController.inMemory(library: fixtureLibrary());
    rolls = inMemoryRolls(settings: settings, location: location);
    tiles = _FakeTiles();
    vectorTiles = FakeVectorTiles();
    vectors = FakeVectorStyles(vectorTiles);
  });
  tearDown(() {
    rolls.dispose();
    gear.dispose();
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 3; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pumpAndSettle();
    }
  }

  /// Lets the vector layer start (its background isolates take a moment
  /// of real time) and draw: a layer taken down before it has started
  /// leaves a cancelled job the package does not catch.
  Future<void> vectorSettle(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  /// A roll of [stock] with a frame at each of [at] (null: no location).
  Future<Roll> roll(WidgetTester t, String stock, List<GeoFix?> at) => t
      .runAsync(() async {
        final r = await rolls.startRoll(
          filmStock: stock,
          filmType: FilmType.bwNeg,
          boxIso: 400,
          pushThirds: 0,
          body: a1,
          size: 36,
          startFrame: StartFrame.one,
        );
        for (final fix in at) {
          await settings.setLocation(fix != null);
          location.fix = fix;
          await rolls.logFrame(const Exposure(aperture: 8, shutter: '1/125'));
          await Future<void>.delayed(Duration.zero);
        }
        await settings.setLocation(true);
        return r;
      })
      .then((r) => r!);

  Future<void> reading(WidgetTester t, GeoFix? at) => t.runAsync(() async {
    await settings.setLocation(at != null);
    location.fix = at;
    await rolls.saveReading(
      const Exposure(aperture: 5.6, shutter: '1/60', iso: 400),
      body: a1,
      format: a1.format,
    );
    await Future<void>.delayed(Duration.zero);
    await settings.setLocation(true);
  });

  Future<void> pump(
    WidgetTester t, {
    String? rollId,
    Brightness brightness = Brightness.light,
    Future<Basemap>? basemap,
    Future<bool> Function()? openSettings,
    TileProvider? tileProvider,
  }) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(brightness),
        home: MapScreen(
          rolls: rolls,
          gear: gear,
          settings: settings,
          rollId: rollId,
          basemap: basemap ?? Future.value(_tinyMap),
          tileProvider: () => tileProvider ?? tiles,
          vectorStyles: () => vectors,
          openSettings: openSettings ?? () async => true,
        ),
      ),
    );
    await settle(t);
  }

  /// A marker, by the label it gives assistive technology.
  Finder pin(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );

  Finder item(String label) =>
      find.widgetWithText(CheckedPopupMenuItem<String>, label);

  testWidgets('with nothing located, it explains Save location', (t) async {
    await roll(t, 'Ilford HP5 Plus', [null, null]);
    await reading(t, null);
    await pump(t);
    expect(find.byType(FlutterMap), findsNothing);
    expect(
      find.textContaining('Turn on Settings > Save location'),
      findsOneWidget,
    );
  });

  testWidgets('a roll without located frames says so', (t) async {
    final r = await roll(t, 'Ilford HP5 Plus', [null]);
    await reading(t, _berlin);
    await pump(t, rollId: r.id);
    expect(find.text('Roll 1 · Map'), findsOneWidget);
    expect(
      find.textContaining('No frame of this roll has a location'),
      findsOneWidget,
    );
  });

  testWidgets('frames and readings with a location get markers, the offline '
      'layers draw, and no tiles load with the setting off', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich, null, _berlin]);
    await reading(t, _berlin);
    await reading(t, null);
    await pump(t);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(pin('Roll 1, frame 1'), findsOneWidget);
    expect(pin('Roll 1, frame 3'), findsOneWidget);
    expect(pin('Roll 1, frame 2'), findsNothing);
    expect(pin('Saved reading'), findsOneWidget);
    expect(find.byType(BasemapLayer), findsOneWidget);
    expect(find.byType(PlaceLabels), findsOneWidget);
    expect(find.byType(PolygonLayer), findsNothing);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.text(osmAttribution), findsNothing);
    expect(find.text('Natural Earth'), findsOneWidget);
    expect(tiles.requests, 0);
    expect(find.bySemanticsLabel('Show all'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Show all'));
    await settle(t);
    expect(pin('Roll 1, frame 1'), findsOneWidget);
  });

  testWidgets('a basemap that fails to load is said, not left blank', (
    t,
  ) async {
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    final failing = Completer<Basemap>();
    await pump(t, brightness: Brightness.dark, basemap: failing.future);
    failing.completeError(const FormatException('Basemap: truncated'));
    await settle(t);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(BasemapLayer), findsNothing);
    expect(pin('Roll 1, frame 1'), findsOneWidget);
    expect(
      find.textContaining('offline map could not be loaded'),
      findsOneWidget,
    );
  });

  testWidgets('one located frame opens at a finite zoom', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t, brightness: Brightness.dark);
    final camera = MapCamera.of(t.element(find.byType(BasemapLayer)));
    expect(camera.zoom, 13);
    expect(camera.center.longitude, closeTo(_munich.longitude, 1e-6));
    expect(find.byType(BasemapLayer), findsOneWidget);
  });

  testWidgets('with the Standard style, OSM tiles draw over the offline '
      'layers with the attribution, as served in dark mode too', (t) async {
    await settings.setMapStyle(MapStyle.standard);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t, brightness: Brightness.dark);
    final layer = t.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(layer.panBuffer, 0);
    expect(layer.maxNativeZoom, 19);
    expect(
      find.ancestor(
        of: find.byType(TileLayer),
        matching: find.byType(ColorFiltered),
      ),
      findsNothing,
    );
    expect(find.byType(BasemapLayer), findsOneWidget);
    // The tiles draw over the basemap, the markers over the tiles.
    final children = t.widget<FlutterMap>(find.byType(FlutterMap)).children;
    expect(
      children.indexWhere((w) => w is BasemapLayer),
      lessThan(children.indexWhere((w) => w is TileLayer)),
    );
    expect(
      children.indexWhere((w) => w is TileLayer),
      lessThan(children.indexWhere((w) => w is MarkerLayer)),
    );
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(tiles.requests, greaterThan(0));
    await settings.setMapStyle(MapStyle.offline);
    await settle(t);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.text('Natural Earth'), findsOneWidget);
  });

  test('the online provider names Grain and its repository', () {
    expect(osmUserAgent, startsWith('Grain/'));
    expect(osmUserAgent, contains('https://github.com/wladiKrin/grain'));
  });

  test('each style names its server, zoom, filter and attribution', () {
    for (final b in Brightness.values) {
      expect(OnlineTiles.of(MapStyle.offline, b), isNull);
    }
    // Streets and Minimal are OpenFreeMap vector styles, not raster tiles.
    for (final b in Brightness.values) {
      expect(OnlineTiles.of(MapStyle.streets, b), isNull);
      expect(OnlineTiles.of(MapStyle.minimal, b), isNull);
      expect(OnlineMap.of(MapStyle.offline, b), isNull);
      expect(
        OnlineMap.of(MapStyle.streets, b),
        const VectorMap(OpenFreeMapStyle.liberty),
      );
      expect(
        OnlineMap.of(MapStyle.streets, b)!.attribution,
        'OpenFreeMap © OpenMapTiles Data from OpenStreetMap',
      );
      for (final s in [
        MapStyle.muted,
        MapStyle.standard,
        MapStyle.topographic,
      ]) {
        expect(
          OnlineMap.of(s, b),
          OnlineTiles.of(s, b) == null ? isNull : isA<OnlineTiles>(),
        );
      }
    }
    expect(
      OnlineMap.of(MapStyle.minimal, Brightness.light),
      const VectorMap(OpenFreeMapStyle.positron),
    );
    expect(
      OnlineMap.of(MapStyle.minimal, Brightness.dark),
      const VectorMap(OpenFreeMapStyle.dark),
    );

    final mutedLight = OnlineTiles.of(MapStyle.muted, Brightness.light)!;
    final mutedDark = OnlineTiles.of(MapStyle.muted, Brightness.dark)!;
    for (final m in [mutedLight, mutedDark]) {
      expect(m.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
      expect(m.subdomains, isEmpty);
      expect(m.maxNativeZoom, 19);
      expect(m.attribution, '© OpenStreetMap contributors');
    }
    expect(mutedLight.colorFilter, OnlineTiles.mutedLightFilter);
    expect(mutedDark.colorFilter, OnlineTiles.mutedDarkFilter);

    for (final b in Brightness.values) {
      final s = OnlineTiles.of(MapStyle.standard, b)!;
      expect(s.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
      expect(s.colorFilter, isNull);
      expect(s.attribution, '© OpenStreetMap contributors');

      final topo = OnlineTiles.of(MapStyle.topographic, b)!;
      expect(
        topo.urlTemplate,
        'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
      );
      expect(topo.subdomains, ['a', 'b', 'c']);
      expect(topo.maxNativeZoom, 17);
      expect(topo.colorFilter, isNull);
      expect(
        topo.attribution,
        '© OpenStreetMap contributors, SRTM · © OpenTopoMap (CC-BY-SA)',
      );
    }
  });

  /// The raster tile layer of an online raster style.
  final rasterTiles = find.byKey(const ValueKey('online-tiles'));

  /// The filter drawn over the tile layer, or null.
  ColorFilter? tileFilter(WidgetTester t) {
    final f = find.ancestor(
      of: find.byType(TileLayer),
      matching: find.byType(ColorFiltered),
    );
    if (f.evaluate().isEmpty) return null;
    return t.widget<ColorFiltered>(f.first).colorFilter;
  }

  for (final brightness in Brightness.values) {
    testWidgets('each style draws its tiles in ${brightness.name} mode', (
      t,
    ) async {
      await roll(t, 'Ilford HP5 Plus', [_munich]);
      for (final style in MapStyle.values) {
        await settings.setMapStyle(style);
        await pump(t, brightness: brightness);
        final online = OnlineMap.of(style, brightness);
        if (online == null) {
          expect(find.byType(TileLayer), findsNothing, reason: style.name);
          expect(find.text('Natural Earth'), findsOneWidget);
          continue;
        }
        if (online case VectorMap(style: final vector)) {
          await vectorSettle(t);
          expect(vectorTiles.requests, greaterThan(0));
          expect(rasterTiles, findsNothing, reason: style.name);
          final layer = t.widget<VectorTileLayer>(find.byType(VectorTileLayer));
          expect(layer.theme.id, 'openfreemap-${vector.name}');
          expect(layer.layerMode, VectorTileLayerMode.raster);
          expect(layer.fileCacheMaximumSizeInBytes, vectorCacheBytes);
          expect(vectors.loaded.last, vector);
          expect(vector, switch ((style, brightness)) {
            (MapStyle.streets, _) => OpenFreeMapStyle.liberty,
            (_, Brightness.dark) => OpenFreeMapStyle.dark,
            _ => OpenFreeMapStyle.positron,
          });
          expect(find.text(openFreeMapAttribution), findsOneWidget);
          expect(find.byType(BasemapLayer), findsOneWidget);
          continue;
        }
        final want = online as OnlineTiles;
        expect(find.byType(VectorTileLayer), findsNothing);
        final layer = t.widget<TileLayer>(rasterTiles);
        expect(layer.urlTemplate, want.urlTemplate, reason: style.name);
        expect(layer.maxNativeZoom, want.maxNativeZoom, reason: style.name);
        expect(layer.panBuffer, 0);
        expect(
          layer.resolvedRetinaMode,
          want.retina ? RetinaMode.server : RetinaMode.disabled,
          reason: style.name,
        );
        expect(
          layer.evictErrorTileStrategy,
          EvictErrorTileStrategy.notVisibleRespectMargin,
        );
        expect(layer.tileProvider, same(tiles));
        expect(tileFilter(t), want.colorFilter, reason: style.name);
        expect(find.text(want.attribution), findsOneWidget);
        expect(find.byType(BasemapLayer), findsOneWidget);
      }
      await t.pump(const Duration(seconds: 4));
    });
  }

  testWidgets('the layers button lists the styles; picking one saves it and '
      'redraws the map', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    expect(find.byType(TileLayer), findsNothing);
    await t.tap(find.byTooltip('Map style'));
    await settle(t);
    expect(find.text('MAP STYLE'), findsOneWidget);
    for (final name in mapStyleLabels.values) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Built into Grain; nothing goes online'), findsOneWidget);

    await t.tap(find.text('Muted'));
    await settle(t);
    expect(settings.mapStyle, MapStyle.muted);
    expect(find.text('MAP STYLE'), findsNothing);
    expect(find.byType(TileLayer), findsOneWidget);
    expect(tileFilter(t), OnlineTiles.mutedLightFilter);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

    await t.tap(find.byTooltip('Map style'));
    await settle(t);
    await t.tap(find.text('Topographic'));
    await settle(t);
    expect(settings.mapStyle, MapStyle.topographic);
    expect(
      t.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
      contains('opentopomap.org'),
    );
    expect(tileFilter(t), isNull);

    await t.tap(find.byTooltip('Map style'));
    await settle(t);
    await t.tap(find.text('Offline'));
    await settle(t);
    expect(settings.mapStyle, MapStyle.offline);
    expect(settings.onlineMap, isFalse);
    expect(find.byType(TileLayer), findsNothing);
    expect(find.text('Natural Earth'), findsOneWidget);
  });

  testWidgets('tiles that fail say so over the offline map; Open settings '
      'opens them, and a tile that loads later clears the note', (t) async {
    var opened = 0;
    await settings.setMapStyle(MapStyle.muted);
    tiles.fail = true;
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(
      t,
      openSettings: () async {
        opened++;
        return true;
      },
    );
    expect(tiles.requests, greaterThanOrEqualTo(MapScreen.failuresBeforeNote));
    expect(find.textContaining('Couldn’t load the online map'), findsOneWidget);
    expect(find.textContaining('allow Network for Grain'), findsOneWidget);
    // The offline map stays in view.
    expect(find.byType(BasemapLayer), findsOneWidget);
    expect(pin('Roll 1, frame 1'), findsOneWidget);

    await t.tap(find.text('Open settings'));
    await settle(t);
    expect(opened, 1);

    // Back from the settings with the network allowed: the tiles are asked
    // for again, load, and the note goes.
    tiles.fail = false;
    final before = tiles.requests;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(tiles.requests, greaterThan(before));
    expect(find.textContaining('load the online map'), findsNothing);
  });

  testWidgets('the failure note can be dismissed, and shows for nothing '
      'when the style is offline', (t) async {
    tiles.fail = true;
    await settings.setMapStyle(MapStyle.standard);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    expect(find.textContaining('load the online map'), findsOneWidget);
    await t.tap(find.byTooltip('Dismiss'));
    await settle(t);
    expect(find.textContaining('load the online map'), findsNothing);
    await settings.setMapStyle(MapStyle.offline);
    await settle(t);
    expect(find.textContaining('load the online map'), findsNothing);
    final before = tiles.requests;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(tiles.requests, before);
  });

  testWidgets('a few failures among loading tiles show no note', (t) async {
    tiles.failFirst = MapScreen.failuresBeforeNote - 1;
    await settings.setMapStyle(MapStyle.standard);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    expect(tiles.requests, greaterThan(MapScreen.failuresBeforeNote));
    expect(find.textContaining('load the online map'), findsNothing);
  });

  /// Each raster tile on the map.
  List<TileImage> shown(WidgetTester t) => [
    for (final e
        in find
            .descendant(
              of: rasterTiles,
              matching: find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == 'Tile',
              ),
            )
            .evaluate())
      (e.widget as dynamic).tileImage as TileImage,
  ];

  testWidgets('raster tiles that failed load again when the map comes to '
      'rest, and the note goes', (t) async {
    final server = FakeServer(
      failFirst: 1,
      failure: () => http.Response('busy', 503),
    );
    await settings.setMapStyle(MapStyle.standard);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(
      t,
      tileProvider: GrainTileProvider(fetcher: server.fetcher(attempts: 1)),
    );
    final failed = shown(t).where((i) => i.loadError).length;
    expect(failed, greaterThanOrEqualTo(MapScreen.failuresBeforeNote));
    expect(find.textContaining('load the online map'), findsOneWidget);

    // The server answers now: a small move, and every tile loads.
    server.failFirst = 0;
    await t.drag(find.byType(FlutterMap), const Offset(40, 30));
    await settle(t);
    expect(shown(t), isNotEmpty);
    expect(notLoaded(shown(t)), isEmpty);
    expect(server.agents, {'Grain/test'});
    expect(find.textContaining('load the online map'), findsNothing);
  });

  testWidgets('tiles given up as they leave the map are no failures: no '
      'note, and the tiles in view load', (t) async {
    final server = FakeServer()..gate = Completer<void>();
    await settings.setMapStyle(MapStyle.topographic);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t, tileProvider: GrainTileProvider(fetcher: server.fetcher()));
    // Far away before anything loads, and back.
    for (final d in const [
      Offset(-900, 0),
      Offset(0, -900),
      Offset(900, 900),
    ]) {
      await t.drag(find.byType(FlutterMap), d);
      await t.pump(const Duration(milliseconds: 50));
      await t.runAsync(pumpEventQueue);
    }
    server.gate!.complete();
    server.gate = null;
    await settle(t);
    expect(server.aborted, greaterThan(0));
    expect(notLoaded(shown(t)), isEmpty);
    expect(find.textContaining('load the online map'), findsNothing);
  });

  testWidgets('Streets draws OpenFreeMap’s vector map between the offline '
      'map and the markers, credited as OpenFreeMap asks', (t) async {
    await settings.setMapStyle(MapStyle.streets);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    await vectorSettle(t);
    expect(vectors.loaded, [OpenFreeMapStyle.liberty]);
    expect(rasterTiles, findsNothing);
    final children = t.widget<FlutterMap>(find.byType(FlutterMap)).children;
    final at = children.indexWhere((w) => w is VectorTileLayer);
    expect(children.indexWhere((w) => w is BasemapLayer), lessThan(at));
    expect(at, lessThan(children.indexWhere((w) => w is MarkerLayer)));
    expect(
      find.text('OpenFreeMap © OpenMapTiles Data from OpenStreetMap'),
      findsOneWidget,
    );
    expect(vectorTiles.requests, greaterThan(0));
    expect(pin('Roll 1, frame 1'), findsOneWidget);
    await settings.setMapStyle(MapStyle.offline);
    await settle(t);
    expect(find.byType(VectorTileLayer), findsNothing);
    expect(find.text('Natural Earth'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('vector tiles that fail say so; after a move they are asked '
      'for again, load, and the note goes', (t) async {
    vectorTiles.fail = true;
    await settings.setMapStyle(MapStyle.minimal);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    await vectorSettle(t);
    expect(
      vectorTiles.requests,
      greaterThanOrEqualTo(MapScreen.failuresBeforeNote),
    );
    expect(find.textContaining('load the online map'), findsOneWidget);
    expect(find.byType(BasemapLayer), findsOneWidget);

    vectorTiles.fail = false;
    final before = vectorTiles.requests;
    await t.drag(find.byType(FlutterMap), const Offset(40, 30));
    await settle(t);
    await vectorSettle(t);
    expect(vectorTiles.requests, greaterThan(before));
    expect(find.textContaining('load the online map'), findsNothing);
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('a vector style that cannot be read shows the note at once, '
      'and is read again on coming back to the app', (t) async {
    vectors.fail = true;
    await settings.setMapStyle(MapStyle.streets);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    expect(find.byType(VectorTileLayer), findsNothing);
    expect(find.textContaining('load the online map'), findsOneWidget);
    expect(find.text(openFreeMapAttribution), findsOneWidget);

    vectors.fail = false;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    await vectorSettle(t);
    expect(vectors.loaded, [OpenFreeMapStyle.liberty]);
    expect(find.byType(VectorTileLayer), findsOneWidget);
    expect(find.textContaining('load the online map'), findsNothing);
    await t.pump(const Duration(seconds: 4));
  });

  test('CARTO is gone: no style, server or credit names it', () {
    final strings = [
      ...mapStyleLabels.values,
      ...mapStyleSubtitles.values,
      for (final s in MapStyle.values)
        for (final b in Brightness.values) ?OnlineMap.of(s, b)?.attribution,
      for (final s in MapStyle.values)
        for (final b in Brightness.values) ?OnlineTiles.of(s, b)?.urlTemplate,
    ];
    for (final s in strings) {
      expect(s.toLowerCase(), isNot(contains('carto')));
    }
    for (final dir in ['lib', 'docs', 'fastlane', 'android/app/src/main']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File) continue;
        expect(
          utf8.decode(f.readAsBytesSync(), allowMalformed: true).toLowerCase(),
          isNot(contains('carto')),
          reason: f.path,
        );
      }
    }
    expect(
      File('README.md').readAsStringSync().toLowerCase(),
      isNot(contains('carto')),
    );
  });

  testWidgets('the roll filter shows one roll or the readings', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await t.runAsync(() => rolls.finishRoll(rolls.active!.id));
    await roll(t, 'Kodak Portra 400', [_berlin, _berlin]);
    await reading(t, _munich);
    await pump(t);
    expect(pin('Roll 1, frame 1'), findsOneWidget);
    expect(pin('Roll 2, frame 2'), findsOneWidget);
    expect(pin('Saved reading'), findsOneWidget);

    await t.tap(find.byTooltip('Filter by roll'));
    await settle(t);
    expect(find.text('Everything'), findsOneWidget);
    expect(find.text('Roll 1 · Ilford HP5 Plus'), findsOneWidget);
    expect(find.text('Saved readings'), findsOneWidget);
    await t.tap(item('Roll 2 · Kodak Portra 400'));
    await settle(t);
    expect(pin('Roll 1, frame 1'), findsNothing);
    expect(pin('Saved reading'), findsNothing);
    expect(pin('Roll 2, frame 1'), findsOneWidget);
    expect(pin('Roll 2, frame 2'), findsOneWidget);

    await t.tap(find.byTooltip('Filter by roll'));
    await settle(t);
    await t.tap(item('Saved readings'));
    await settle(t);
    expect(pin('Saved reading'), findsOneWidget);
    expect(pin('Roll 2, frame 1'), findsNothing);
  });

  testWidgets('a roll map has only that roll and no filter', (t) async {
    final first = await roll(t, 'Ilford HP5 Plus', [_munich]);
    await t.runAsync(() => rolls.finishRoll(first.id));
    await roll(t, 'Kodak Portra 400', [_berlin]);
    await reading(t, _munich);
    await pump(t, rollId: first.id);
    expect(pin('Roll 1, frame 1'), findsOneWidget);
    expect(pin('Roll 2, frame 1'), findsNothing);
    expect(pin('Saved reading'), findsNothing);
    expect(find.byTooltip('Filter by roll'), findsNothing);
  });

  testWidgets('tapping a frame shows its card; the card opens the frame '
      'editor', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich, _berlin]);
    await pump(t);
    await t.tap(pin('Roll 1, frame 2'));
    await settle(t);
    expect(find.text('Roll 1 · Frame 2'), findsOneWidget);
    expect(find.text('Roll 1 · Frame 1'), findsNothing);
    expect(find.text('Ilford HP5 Plus · Canon A-1'), findsOneWidget);
    final f = rolls.activeFrames[1];
    final w = f.takenAt!.toUtc().add(Duration(minutes: f.utcOffsetMinutes!));
    expect(find.textContaining('${w.year}'), findsOneWidget);
    await t.tap(find.text('Roll 1 · Frame 2'));
    await settle(t);
    expect(find.byType(FrameEditorScreen), findsOneWidget);
    expect(
      t.widget<FrameEditorScreen>(find.byType(FrameEditorScreen)).frame.id,
      f.id,
    );
  });

  testWidgets('frames logged at one spot are all in the card', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich, _munich, _berlin]);
    await pump(t);
    await t.tap(pin('Roll 1, frame 2'));
    await settle(t);
    expect(find.text('Roll 1 · Frame 1'), findsOneWidget);
    expect(find.text('Roll 1 · Frame 2'), findsOneWidget);
    expect(find.text('Roll 1 · Frame 3'), findsNothing);
    await t.tap(find.byTooltip('Close'));
    await settle(t);
    expect(find.text('Roll 1 · Frame 1'), findsNothing);
  });

  testWidgets('tapping a reading opens the reading', (t) async {
    await reading(t, _berlin);
    await pump(t);
    await t.tap(pin('Saved reading'));
    await settle(t);
    expect(find.text('Saved reading'), findsOneWidget);
    expect(find.text('Canon A-1'), findsOneWidget);
    await t.tap(find.text('Saved reading'));
    await settle(t);
    expect(find.byType(ReadingScreen), findsOneWidget);
  });

  testWidgets('a location deleted in the editor leaves the map', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich, _berlin]);
    await pump(t);
    expect(pin('Roll 1, frame 1'), findsOneWidget);
    final r = rolls.active!;
    await t.runAsync(
      () => rolls.deleteFrameLocation(r.id, rolls.activeFrames.first.id),
    );
    await settle(t);
    expect(pin('Roll 1, frame 1'), findsNothing);
    expect(pin('Roll 1, frame 2'), findsOneWidget);
  });
}
