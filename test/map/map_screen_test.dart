import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/map/map_network.dart';
import 'package:grain/map/map_screen.dart';
import 'package:grain/map/map_style_sheet.dart';
import 'package:grain/map/map_styles.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/rolls/ui/frame_editor.dart';
import 'package:grain/rolls/ui/reading_screen.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_location.dart';
import '../support/gear_fixtures.dart';
import '../support/rolls_fixtures.dart';
import 'fake_map_view.dart';

const _munich = GeoFix(latitude: 48.137, longitude: 11.575);
const _berlin = GeoFix(latitude: 52.52, longitude: 13.405);

/// Offline basemap files that are not read (the fake map draws nothing).
const _offline = OfflineSources(
  data: {
    'land': 'file:///cache/map/land.geojson',
    'lakes': 'file:///cache/map/lakes.geojson',
    'coast': 'file:///cache/map/coast.geojson',
    'borders': 'file:///cache/map/borders.geojson',
    'places': 'file:///cache/map/places.geojson',
  },
  placeZooms: [0, 2, 5],
);

const _osmTile = 'https://tile.openstreetmap.org/12/2177/1420.png';

void main() {
  late Settings settings;
  late FakeLocation location;
  late RollController rolls;
  late GearController gear;
  late FakeMap map;
  late FakeNetwork network;
  final a1 = libBody('canon-a1');

  setUp(() async {
    settings = Settings.inMemory();
    await settings.setLocation(true);
    await settings.setSnapshots(false);
    location = FakeLocation(_munich);
    gear = GearController.inMemory(library: fixtureLibrary());
    rolls = inMemoryRolls(settings: settings, location: location);
    map = FakeMap();
    network = FakeNetwork();
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

  Widget app(
    Brightness brightness, {
    String? rollId,
    Future<OfflineSources>? offline,
    Future<bool> Function()? openSettings,
  }) => MaterialApp(
    theme: grainTheme(brightness),
    home: MapScreen(
      rolls: rolls,
      gear: gear,
      settings: settings,
      rollId: rollId,
      offline: offline ?? Future.value(_offline),
      network: network,
      mapView: map.build,
      openSettings: openSettings ?? () async => true,
    ),
  );

  Future<void> pump(
    WidgetTester t, {
    String? rollId,
    Brightness brightness = Brightness.light,
    Future<OfflineSources>? offline,
    Future<bool> Function()? openSettings,
  }) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      app(
        brightness,
        rollId: rollId,
        offline: offline,
        openSettings: openSettings,
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

  /// The style the map shows, as JSON; null for a style URL.
  Map<String, Object?>? styleJson() {
    final s = map.last.style.style;
    return s.startsWith('{') ? jsonDecode(s) as Map<String, Object?> : null;
  }

  Map<String, Object?>? source(String id) =>
      ((styleJson()?['sources'] as Map?)?[id] as Map?)?.cast<String, Object?>();

  Finder note() => find.textContaining('Couldn’t load the online map');

  testWidgets('with nothing located, it explains Save location', (t) async {
    await roll(t, 'Ilford HP5 Plus', [null, null]);
    await reading(t, null);
    await pump(t);
    expect(map.builds, isEmpty);
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

  testWidgets('frames and readings with a location get markers on the '
      'offline map, and nothing may go online', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich, null, _berlin]);
    await reading(t, _berlin);
    await reading(t, null);
    await pump(t);
    expect(pin('Roll 1, frame 1'), findsOneWidget);
    expect(pin('Roll 1, frame 3'), findsOneWidget);
    expect(pin('Roll 1, frame 2'), findsNothing);
    expect(pin('Saved reading'), findsOneWidget);
    expect(network.configured, [(userAgent: osmUserAgent, offline: true)]);
    // Only the offline style was ever shown, written here from the
    // bundled basemap.
    expect(map.styles, hasLength(1));
    expect(source('land')!['data'], 'file:///cache/map/land.geojson');
    expect(styleJson()!['glyphs'], glyphsUrl);
    expect(map.last.style.online, isFalse);
    expect(find.text('Natural Earth'), findsOneWidget);
    expect(find.text(osmAttribution), findsNothing);
    expect(find.bySemanticsLabel('Show all'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Show all'));
    await settle(t);
    expect(map.moves, hasLength(1));
    expect(map.moves.single, map.last.initialCamera);
  });

  testWidgets('a basemap that fails to load is said, not left blank', (
    t,
  ) async {
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    final failing = Completer<OfflineSources>();
    await pump(t, brightness: Brightness.dark, offline: failing.future);
    expect(map.builds, isEmpty);
    failing.completeError(const FormatException('Basemap: truncated'));
    await settle(t);
    expect(pin('Roll 1, frame 1'), findsOneWidget);
    expect(source('land'), isNull);
    expect(
      (styleJson()!['layers']! as List).single,
      containsPair('id', 'water'),
    );
    expect(
      find.textContaining('offline map could not be loaded'),
      findsOneWidget,
    );
  });

  testWidgets('one located frame opens at a finite zoom', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t, brightness: Brightness.dark);
    final camera = map.last.initialCamera;
    expect(camera.zoom, 13);
    expect(camera.center.longitude, closeTo(_munich.longitude, 1e-6));
    // The spot sits above the card: the camera looks a little south of it.
    expect(camera.center.latitude, lessThan(_munich.latitude));
  });

  testWidgets('with the Standard style, OSM tiles draw over the offline '
      'land with the attribution; back to Offline, the client goes offline '
      'before the map changes', (t) async {
    await settings.setMapStyle(MapStyle.standard);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t, brightness: Brightness.dark);
    expect(network.configured.last.offline, isFalse);
    expect(source('raster')!['tiles'], [RasterTiles.osmTiles]);
    expect(source('raster')!['tileSize'], 256);
    expect(source('land'), isNotNull);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

    network.hold = Completer<void>();
    await settings.setMapStyle(MapStyle.offline);
    await t.pump();
    expect(network.configured.last.offline, isTrue);
    // Still Standard until the client is set.
    expect(source('raster'), isNotNull);
    network.hold!.complete();
    await settle(t);
    expect(source('raster'), isNull);
    expect(map.last.style.online, isFalse);
    expect(find.text('Natural Earth'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('each style shows as chosen in ${brightness.name} mode', (
      t,
    ) async {
      await roll(t, 'Ilford HP5 Plus', [_munich]);
      await pump(t, brightness: brightness);
      final g = GrainPalette.of(brightness);
      for (final style in MapStyle.values) {
        await settings.setMapStyle(style);
        await settle(t);
        final want = mapStyleFor(
          style,
          brightness,
          MapColors.of(g, brightness),
          _offline,
        );
        expect(map.last.style, want, reason: style.name);
        expect(network.configured.last.offline, !style.online);
        expect(find.text(want.attribution), findsOneWidget);
      }
    });
  }

  testWidgets('switching to dark mode with the map open shows the dark '
      'style and keeps the markers', (t) async {
    await settings.setMapStyle(MapStyle.minimal);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    expect(map.last.style.style, OpenFreeMapStyle.positron.url);
    await t.pumpWidget(app(Brightness.dark));
    await settle(t);
    expect(map.last.style.style, OpenFreeMapStyle.dark.url);
    expect(pin('Roll 1, frame 1'), findsOneWidget);
    expect(
      map.props(map.features.single)['fill'],
      cssColor(GrainPalette.of(Brightness.dark).accent),
    );
  });

  testWidgets('the layers button lists the styles; picking one saves it and '
      'redraws the map', (t) async {
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
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
    final raster = (styleJson()!['layers']! as List).last as Map;
    expect(raster['paint'], RasterTiles.mutedLight);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

    await t.tap(find.byTooltip('Map style'));
    await settle(t);
    await t.tap(find.text('Topographic'));
    await settle(t);
    expect(settings.mapStyle, MapStyle.topographic);
    expect(source('raster')!['maxzoom'], 17);
    expect(
      (source('raster')!['tiles']! as List).first,
      contains('opentopomap.org'),
    );

    await t.tap(find.byTooltip('Map style'));
    await settle(t);
    await t.tap(find.text('Offline'));
    await settle(t);
    expect(settings.mapStyle, MapStyle.offline);
    expect(settings.onlineMap, isFalse);
    expect(source('raster'), isNull);
    expect(find.text('Natural Earth'), findsOneWidget);
  });

  testWidgets('requests that fail say so over the map; Open settings opens '
      'them, and coming back asks again; an answer clears the note', (t) async {
    var opened = 0;
    await settings.setMapStyle(MapStyle.muted);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(
      t,
      openSettings: () async {
        opened++;
        return true;
      },
    );
    for (var i = 0; i < MapFailures.failuresBeforeNote - 1; i++) {
      network.request(_osmTile, ok: false);
    }
    await settle(t);
    expect(note(), findsNothing);
    network.request(_osmTile, ok: false);
    await settle(t);
    expect(note(), findsOneWidget);
    expect(find.textContaining('allow Network for Grain'), findsOneWidget);
    expect(pin('Roll 1, frame 1'), findsOneWidget);

    await t.tap(find.text('Open settings'));
    await settle(t);
    expect(opened, 1);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(map.reloads, 1);
    network.request(_osmTile);
    await settle(t);
    expect(note(), findsNothing);
  });

  testWidgets('failures of another server or of a request refused offline '
      'show no note', (t) async {
    await settings.setMapStyle(MapStyle.standard);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    for (var i = 0; i < 5; i++) {
      network.request(
        'https://tiles.openfreemap.org/planet/1/0/0.pbf',
        ok: false,
      );
    }
    await settle(t);
    expect(note(), findsNothing);
  });

  testWidgets('the failure note can be dismissed, and shows for nothing '
      'when the style is offline', (t) async {
    await settings.setMapStyle(MapStyle.standard);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    for (var i = 0; i < MapFailures.failuresBeforeNote; i++) {
      network.request(_osmTile, ok: false);
    }
    await settle(t);
    expect(note(), findsOneWidget);
    await t.tap(find.byTooltip('Dismiss'));
    await settle(t);
    expect(note(), findsNothing);
    await settings.setMapStyle(MapStyle.offline);
    await settle(t);
    expect(note(), findsNothing);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(map.reloads, 0);
  });

  testWidgets('a style that cannot be read shows the note at once', (t) async {
    await settings.setMapStyle(MapStyle.streets);
    await roll(t, 'Ilford HP5 Plus', [_munich]);
    await pump(t);
    expect(map.last.style.style, OpenFreeMapStyle.liberty.url);
    network.request(OpenFreeMapStyle.liberty.url, ok: false);
    await settle(t);
    expect(note(), findsOneWidget);
    expect(find.text(openFreeMapAttribution), findsOneWidget);
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

    // A tap on the map away from the markers closes the card too.
    await t.tap(pin('Roll 1, frame 3'));
    await settle(t);
    expect(find.text('Roll 1 · Frame 3'), findsOneWidget);
    await t.tapAt(
      t.getBottomLeft(find.byKey(const ValueKey('fake-map'))) +
          const Offset(20, -200),
    );
    await settle(t);
    expect(find.text('Roll 1 · Frame 3'), findsNothing);
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
