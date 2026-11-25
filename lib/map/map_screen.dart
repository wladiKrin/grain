import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:vector_map_tiles/vector_map_tiles.dart'
    show Style, VectorTileLayer, VectorTileLayerMode;

import '../gear/gear_controller.dart';
import '../gear/model.dart';
import '../rolls/roll_controller.dart';
import '../rolls/ui/frame_editor.dart';
import '../rolls/ui/reading_screen.dart';
import '../settings/settings.dart';
import '../ui/permissions.dart';
import '../ui/round_button.dart';
import '../ui/theme.dart';
import 'basemap.dart';
import 'map_layers.dart';
import 'map_points.dart';
import 'map_style_sheet.dart';
import 'tile_loading.dart';
import 'vector_map.dart';

/// The all-rolls map's filter: everything, saved readings only, or a roll.
const _allFilter = '';
const _readingsFilter = '\u0000readings';

/// Logged locations on a map: every located frame and saved reading, or
/// only the frames of [rollId]. The basemap is the bundled one; with an
/// online map style chosen, that style's raster tiles or vector map are
/// drawn over it.
class MapScreen extends StatefulWidget {
  MapScreen({
    super.key,
    required this.rolls,
    required this.gear,
    required this.settings,
    this.rollId,
    Future<Basemap>? basemap,
    this.tileProvider = onlineTileProvider,
    this.vectorStyles = openFreeMap,
    this.openSettings = openAppSettings,
  }) : basemap = basemap ?? loadBasemap();

  final RollController rolls;

  /// Bodies and lenses for the frame editor.
  final GearController gear;

  /// The map style ([Settings.mapStyle]).
  final Settings settings;

  /// Opened from the note shown when online tiles do not load.
  final OpenSettings openSettings;

  /// Tiles that fail with none loading in between before the note shows.
  static const failuresBeforeNote = 3;

  /// Only this roll's frames; null shows every roll and the saved readings.
  final String? rollId;
  final Future<Basemap> basemap;

  /// Makes the online tile provider, once each time the tiles are turned on
  /// (tests pass one that never goes to the network).
  final TileProvider Function() tileProvider;

  /// Where the vector styles come from, asked for the first time one is
  /// drawn (tests pass one that never goes to the network).
  final VectorStyleSource Function() vectorStyles;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GrainPalette get g => context.grain;

  final _map = MapController();
  List<MapPoint>? _points;
  int _generation = 0;
  String _filter = _allFilter;

  /// The marker tapped and the points under it, shown in the card.
  List<MapPoint> _selected = const [];
  TileProvider? _tiles;

  /// The raster tile layer last built, to load failed tiles again as it
  /// would.
  TileLayer? _tileLayerShown;
  final _retries = TileRetries();

  late final VectorStyleSource _vectors = widget.vectorStyles();

  /// The vector style asked for, and once read, the style drawn (its
  /// providers reporting to the failure note).
  OpenFreeMapStyle? _vectorWanted;
  Style? _vectorStyle;
  bool _vectorStyleFailed = false;

  /// Vector tiles failed since the vector layer was last built: on the
  /// next move it is built again, asking for them afresh.
  bool _vectorTilesFailed = false;
  int _vectorGeneration = 0;
  DateTime? _lastRetry;

  Basemap? _basemap;

  /// The basemap could not be read: said over the map, not left blank.
  bool _basemapFailed = false;

  /// The style the tiles are drawn in, to notice a change.
  late MapStyle _style = widget.settings.mapStyle;

  /// Online tiles that failed since one last loaded. From
  /// [MapScreen.failuresBeforeNote] on, a note says the map is not loading
  /// (no network, or the network permission off) until a tile loads.
  int _tileFailures = 0;
  bool _noteDismissed = false;
  bool _okPending = false;

  bool get _tilesFailing =>
      _tileFailures >= MapScreen.failuresBeforeNote && !_noteDismissed;

  /// Reloads the tiles in view, as on coming back from the system settings.
  final _resetTiles = StreamController<void>.broadcast();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _retryTiles);
    widget.rolls.addListener(_load);
    widget.settings.addListener(_settingsChanged);
    widget.basemap.then(
      (b) {
        if (mounted) setState(() => _basemap = b);
      },
      onError: (Object _) {
        // No basemap: the markers still show on the water colour, with a
        // note saying why.
        if (mounted) setState(() => _basemapFailed = true);
      },
    );
    _load();
  }

  @override
  void dispose() {
    widget.rolls.removeListener(_load);
    widget.settings.removeListener(_settingsChanged);
    _lifecycle.dispose();
    _resetTiles.close();
    _map.dispose();
    super.dispose();
  }

  void _settingsChanged() {
    if (!mounted) return;
    setState(() {
      if (widget.settings.mapStyle != _style) {
        _style = widget.settings.mapStyle;
        _tileFailures = 0;
        _lastFailure = null;
        _noteDismissed = false;
        _retries.clear();
        _vectorTilesFailed = false;
      }
    });
  }

  void _tileFailed(TileImage tile, Object error, StackTrace? stack) {
    // A load given up as its tile left the map is no failure.
    if (!mounted || isTileCancellation(error)) return;
    _retries.failed(tile);
    _failed(tile.loadFinishedAt ?? DateTime.now());
  }

  void _failed(DateTime at) {
    _tileFailures++;
    _lastFailure = at;
    // Reported while building too (an error already known): redrawn after.
    if (_tileFailures == MapScreen.failuresBeforeNote) {
      scheduleMicrotask(() {
        if (mounted) setState(() {});
      });
    }
  }

  /// When the last tile failed: only a tile loaded since clears the note,
  /// not one loaded before (from the cache, say) and drawn again.
  DateTime? _lastFailure;

  /// Called as tiles are drawn: one that loaded since the last failure
  /// clears the failures (after the frame, as this runs while building).
  Widget _watchTile(BuildContext context, Widget tile, TileImage image) {
    final loaded = image.loadFinishedAt;
    final failed = _lastFailure;
    if (_tileFailures > 0 &&
        !_okPending &&
        loaded != null &&
        !image.loadError &&
        (failed == null || !loaded.isBefore(failed))) {
      _okPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _okPending = false;
        if (!mounted) return;
        setState(() {
          _tileFailures = 0;
          _lastFailure = null;
          _noteDismissed = false;
        });
      });
    }
    return tile;
  }

  /// A vector tile that failed (reported as it happens, from the tile
  /// provider).
  void _vectorTileFailed(Object error) {
    if (!mounted) return;
    _vectorTilesFailed = true;
    _failed(DateTime.now());
  }

  /// A vector tile loaded: the online map works, the failures so far go.
  void _vectorTileLoaded() {
    if (!mounted || _tileFailures == 0 || _okPending) return;
    _okPending = true;
    scheduleMicrotask(() {
      _okPending = false;
      if (!mounted) return;
      setState(() {
        _tileFailures = 0;
        _lastFailure = null;
        _noteDismissed = false;
      });
    });
  }

  /// Reads [style], unless it is the one already read or being read (or,
  /// but for a [retry], that failed); a style that cannot be read shows the
  /// note at once.
  void _wantVectorStyle(OpenFreeMapStyle style, {bool retry = false}) {
    if (_vectorWanted == style && !(retry && _vectorStyleFailed)) return;
    _vectorWanted = style;
    _vectorStyle = null;
    _vectorStyleFailed = false;
    _vectors
        .load(style)
        .then(
          (s) {
            if (!mounted || _vectorWanted != style) return;
            setState(
              () => _vectorStyle = reportingStyle(
                s,
                onLoaded: _vectorTileLoaded,
                onFailed: _vectorTileFailed,
              ),
            );
          },
          onError: (Object _) {
            if (!mounted || _vectorWanted != style) return;
            setState(() {
              _vectorStyleFailed = true;
              _tileFailures = math.max(
                _tileFailures,
                MapScreen.failuresBeforeNote,
              );
              _lastFailure = DateTime.now();
            });
          },
        );
  }

  /// Asks for the tiles in view again if any failed: the network may be
  /// back, or allowed in the system settings.
  void _retryTiles() {
    if (!mounted || !widget.settings.onlineMap) return;
    final online = OnlineMap.of(
      widget.settings.mapStyle,
      Theme.of(context).brightness,
    );
    if (online is VectorMap) {
      if (_vectorStyleFailed) {
        setState(() => _wantVectorStyle(online.style, retry: true));
      } else if (_vectorTilesFailed) {
        setState(() {
          _vectorTilesFailed = false;
          _vectorGeneration++;
        });
      }
    } else if (_tileFailures > 0 || _retries.length > 0) {
      _retries.clear();
      _resetTiles.add(null);
    }
  }

  /// When the map comes to rest, the failed tiles in view are asked for
  /// again (at most every few seconds, so a map with no network is not
  /// asked for over and over).
  void _mapEvent(MapEvent event) {
    if (event is! MapEventMoveEnd &&
        event is! MapEventFlingAnimationEnd &&
        event is! MapEventDoubleTapZoomEnd) {
      return;
    }
    final now = DateTime.now();
    final last = _lastRetry;
    if (last != null && now.difference(last) < retryInterval) return;
    final tiles = _tiles, layer = _tileLayerShown;
    if (tiles != null && layer != null && _retries.length > 0) {
      _lastRetry = now;
      _retries.retry(tiles, layer);
    } else if (_vectorTilesFailed && _vectorStyle != null) {
      _lastRetry = now;
      setState(() {
        _vectorTilesFailed = false;
        _vectorGeneration++;
      });
    } else if (_vectorStyleFailed && _vectorWanted != null) {
      _lastRetry = now;
      setState(() => _wantVectorStyle(_vectorWanted!, retry: true));
    }
  }

  /// Failed tiles are asked for again on a move at most this often.
  static const retryInterval = Duration(seconds: 3);

  Future<void> _load() async {
    final generation = ++_generation;
    final rolls = widget.rolls;
    final List<MapPoint> points;
    if (widget.rollId case final id?) {
      final roll = rolls.rolls.where((r) => r.id == id).firstOrNull;
      points = roll == null
          ? []
          : mapPoints([(roll, await rolls.framesOf(id))]);
    } else {
      points = mapPoints(await rolls.allFrames(), rolls.readings);
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _points = points;
      // The card keeps the records that still have a location.
      _selected = [
        for (final s in _selected) ...points.where((p) => p.id == s.id),
      ];
      if (!_filters(points).containsKey(_filter)) _filter = _allFilter;
    });
  }

  List<MapPoint> get _shown {
    final all = _points ?? const <MapPoint>[];
    return switch (_filter) {
      _allFilter => all,
      _readingsFilter => [
        for (final p in all)
          if (p.isReading) p,
      ],
      final id => [
        for (final p in all)
          if (p.roll?.id == id) p,
      ],
    };
  }

  /// The filters with something to show, and their labels.
  Map<String, String> _filters(List<MapPoint> points) => {
    _allFilter: 'Everything',
    for (final p in points)
      if (p.roll case final r?) r.id: 'Roll ${r.number} · ${r.filmStock}',
    if (points.any((p) => p.isReading)) _readingsFilter: 'Saved readings',
  };

  CameraFit _fit(List<MapPoint> points) =>
      cameraFitFor([for (final p in points) p.position]);

  void _recentre() {
    final shown = _shown;
    if (shown.isNotEmpty) _map.fitCamera(_fit(shown));
  }

  void _setFilter(String f) {
    setState(() {
      _filter = f;
      _selected = const [];
    });
    _recentre();
  }

  /// The points drawn within a marker's reach of [p] at this zoom: the card
  /// lists them all, so frames logged at one spot can each be opened.
  void _tap(MapPoint p) {
    final camera = _map.camera;
    final at = camera.latLngToScreenOffset(p.position);
    final near = [
      for (final q in _shown)
        if ((camera.latLngToScreenOffset(q.position) - at).distance <= 16) q,
    ]..sort(_byTime);
    setState(() => _selected = near.isEmpty ? [p] : near);
  }

  /// Oldest first; undated (blank) frames last.
  static int _byTime(MapPoint a, MapPoint b) =>
      switch ((a.takenAt, b.takenAt)) {
        (final x?, final y?) => x.compareTo(y),
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
      };

  void _open(MapPoint p) {
    final Widget screen;
    if (p.reading case final r?) {
      screen = ReadingScreen(rolls: widget.rolls, readingId: r.id);
    } else {
      final roll = p.roll!;
      screen = FrameEditorScreen(
        rolls: widget.rolls,
        roll: roll,
        frame: p.frame!,
        bodies: [
          for (final Body b in widget.gear.bodies)
            if (b.format == roll.format) b,
        ],
        lensesFor: widget.gear.lensesFor,
      );
    }
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  String get _title {
    if (widget.rollId case final id?) {
      final r = widget.rolls.rolls.where((r) => r.id == id).firstOrNull;
      if (r != null) return 'Roll ${r.number} · Map';
    }
    return 'Map';
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final filters = points == null
        ? const <String, String>{}
        : _filters(points);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (points != null && points.isNotEmpty)
            IconButton(
              tooltip: 'Map style',
              icon: const Icon(Icons.layers),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => showMapStyleSheet(context, widget.settings),
            ),
          if (widget.rollId == null && filters.length > 2)
            PopupMenuButton<String>(
              tooltip: 'Filter by roll',
              icon: const Icon(Icons.filter_list),
              color: g.ground,
              elevation: 0,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              initialValue: _filter,
              onSelected: _setFilter,
              itemBuilder: (_) => [
                for (final e in filters.entries)
                  CheckedPopupMenuItem(
                    value: e.key,
                    checked: e.key == _filter,
                    child: Text(e.value),
                  ),
              ],
            ),
        ],
      ),
      body: points == null
          ? const SizedBox.shrink()
          : points.isEmpty
          ? _empty()
          : _mapView(),
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        widget.rollId == null
            ? 'No frame or reading has a location yet. Turn on Settings > '
                  'Save location, and what you log from then on shows here.'
            : 'No frame of this roll has a location. Turn on Settings > '
                  'Save location, and frames you log from then on show here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: g.secondary, fontSize: 16),
      ),
    ),
  );

  Widget _mapView() {
    final brightness = Theme.of(context).brightness;
    final colors = MapColors.of(g, brightness);
    final basemap = _basemap;
    final online = OnlineMap.of(widget.settings.mapStyle, brightness);
    if (online is! OnlineTiles) {
      _tiles = null;
      _tileLayerShown = null;
    }
    if (online is VectorMap) {
      _wantVectorStyle(online.style);
    } else {
      _vectorWanted = null;
      _vectorStyle = null;
      _vectorStyleFailed = false;
    }
    final vectorStyle = _vectorStyle;
    final shown = _shown;
    final inset = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: _fit(shown),
            backgroundColor: colors.water,
            minZoom: 1,
            maxZoom: 19,
            cameraConstraint: const _ContainLatitude(),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) {
              if (_selected.isNotEmpty) setState(() => _selected = const []);
            },
            onMapEvent: _mapEvent,
          ),
          children: [
            if (basemap != null) ...basemapLayers(basemap, colors),
            if (online is OnlineTiles) _tileLayer(online),
            if (online is VectorMap && vectorStyle != null)
              _vectorLayer(vectorStyle),
            MarkerLayer(
              markers: [
                // Frames over readings; the selected ones on top.
                for (final p in _ordered(shown))
                  Marker(
                    key: ValueKey('map-point-${p.id}'),
                    point: p.position,
                    width: 44,
                    height: 44,
                    child: _Pin(
                      point: p,
                      selected: _selected.contains(p),
                      onTap: () => _tap(p),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Column(
            spacing: 8,
            children: [
              if (_basemapFailed)
                Center(
                  child: _Attribution(
                    'The offline map could not be loaded: only the markers '
                    'show.',
                  ),
                ),
              if (online != null && _tilesFailing)
                _TilesNote(
                  onOpenSettings: widget.openSettings,
                  onDismiss: () => setState(() => _noteDismissed = true),
                ),
            ],
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: inset.bottom + 6,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _Attribution(online?.attribution ?? naturalEarthAttribution),
          ),
        ),
        Positioned(
          right: 16,
          bottom: inset.bottom + 28,
          child: RoundButton(
            semanticLabel: 'Show all',
            background: g.ground,
            onPressed: _recentre,
            child: const Icon(Icons.fit_screen_outlined),
          ),
        ),
        if (_selected.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: inset.bottom + 84,
            child: _PointCard(
              points: _selected,
              onOpen: _open,
              onClose: () => setState(() => _selected = const []),
            ),
          ),
      ],
    );
  }

  /// [online]'s tiles over the basemap, with its colour filter if it has
  /// one. Only what is on screen is asked for, no further in than the
  /// server draws.
  Widget _tileLayer(OnlineTiles online) {
    final layer = TileLayer(
      key: const ValueKey('online-tiles'),
      urlTemplate: online.urlTemplate,
      subdomains: online.subdomains,
      retinaMode: online.retina && RetinaMode.isHighDensity(context),
      tileProvider: _tiles ??= widget.tileProvider(),
      maxNativeZoom: online.maxNativeZoom,
      // No tiles fetched ahead.
      panBuffer: 0,
      // A failed tile is let go once it is off the map (beyond the margin
      // kept), so it is asked for afresh when it comes back.
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
      errorTileCallback: _tileFailed,
      tileBuilder: _watchTile,
      reset: _resetTiles.stream,
    );
    _tileLayerShown = layer;
    final filter = online.colorFilter;
    return filter == null
        ? layer
        : ColorFiltered(colorFilter: filter, child: layer);
  }

  /// [style] drawn with vector_map_tiles as it recommends for speed: each
  /// tile rendered once to an image (in raster mode, so a pan or zoom only
  /// moves images), tiles decoded in background isolates, and the tiles
  /// kept on disk within [vectorCacheBytes]. Only tiles on screen (and the
  /// ring around them the layer keeps) are asked for.
  Widget _vectorLayer(Style style) => VectorTileLayer(
    key: ValueKey('vector-tiles-${style.name}-$_vectorGeneration'),
    theme: style.theme,
    sprites: style.sprites,
    tileProviders: style.providers,
    layerMode: VectorTileLayerMode.raster,
    maximumZoom: 19,
    fileCacheMaximumSizeInBytes: vectorCacheBytes,
    // The package types this with its own `Directory`, which the analyser
    // takes for its web stand-in; on Android it is dart:io's.
    cacheFolder: _vectors.cacheFolder as dynamic,
  );

  Iterable<MapPoint> _ordered(List<MapPoint> shown) => [
    for (final p in shown)
      if (p.isReading && !_selected.contains(p)) p,
    for (final p in shown)
      if (!p.isReading && !_selected.contains(p)) p,
    for (final p in shown)
      if (_selected.contains(p)) p,
  ];
}

/// The camera for [positions]: all in view above the card, at most zoom
/// 13. A single spot (or several at one place) is fitted as a small area
/// around it, so the zoom stays finite whatever the map's size.
CameraFit cameraFitFor(List<LatLng> positions) {
  var coordinates = positions;
  if (positions.isNotEmpty) {
    final b = LatLngBounds.fromPoints(positions);
    if (b.north - b.south < 1e-4 && b.east - b.west < 1e-4) {
      final c = b.center;
      coordinates = [
        LatLng(c.latitude - .005, c.longitude - .005),
        LatLng(c.latitude + .005, c.longitude + .005),
      ];
    }
  }
  return CameraFit.coordinates(
    coordinates: coordinates,
    padding: const EdgeInsets.fromLTRB(48, 48, 48, 160),
    maxZoom: 13,
  );
}

/// Keeps the map's centre between the Mercator edges; east and west it
/// goes round and round (the basemap draws as many copies as show).
class _ContainLatitude extends CameraConstraint {
  const _ContainLatitude();

  @override
  MapCamera constrain(MapCamera camera) {
    final lat = camera.center.latitude;
    if (lat.abs() <= 80) return camera;
    return camera.withPosition(
      center: LatLng(lat.clamp(-80, 80), camera.center.longitude),
    );
  }
}

/// A frame is a filled dot in the accent, a saved reading a ring.
class _Pin extends StatelessWidget {
  const _Pin({
    required this.point,
    required this.selected,
    required this.onTap,
  });

  final MapPoint point;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    final p = point;
    final label = p.isReading
        ? 'Saved reading'
        : 'Roll ${p.roll!.number}, frame ${p.frame!.label}';
    final size = selected ? 20.0 : 16.0;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.isReading ? g.ground : g.accent,
              border: Border.all(
                color: p.isReading ? g.accent : g.ground,
                width: p.isReading ? 3 : 2,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: g.ink, spreadRadius: 1.5)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: g.ground.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(text, style: TextStyle(fontSize: 11, color: g.secondary)),
      ),
    );
  }
}

/// Online tiles are not loading: most likely no connection, or the network
/// permission off (GrapheneOS's Network toggle, which an app cannot ask
/// for). The offline map stays in view under it.
class _TilesNote extends StatelessWidget {
  const _TilesNote({required this.onOpenSettings, required this.onDismiss});

  final OpenSettings onOpenSettings;
  final VoidCallback onDismiss;

  static const text =
      'Couldn’t load the online map. Check your connection, or allow '
      'Network for Grain in its app permissions.';

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return Container(
      decoration: BoxDecoration(
        color: g.ground.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: g.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 0, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: TextStyle(fontSize: 14, color: g.ink)),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 44),
                    foregroundColor: g.ink,
                  ),
                  onPressed: onOpenSettings,
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// The tapped marker's records: roll, frame, date and camera; a row opens
/// the frame editor or the reading.
class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.points,
    required this.onOpen,
    required this.onClose,
  });

  final List<MapPoint> points;
  final void Function(MapPoint p) onOpen;
  final VoidCallback onClose;

  String _when(MaterialLocalizations loc, MapPoint p) {
    final t = p.takenAt;
    if (t == null) return '';
    final w = t.toUtc().add(Duration(minutes: p.utcOffsetMinutes));
    return '${loc.formatShortDate(w)} · '
        '${loc.formatTimeOfDay(TimeOfDay(hour: w.hour, minute: w.minute), alwaysUse24HourFormat: true)}';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    final loc = MaterialLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 232),
      decoration: BoxDecoration(
        color: g.ground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: g.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final p in points)
                  InkWell(
                    onTap: () => onOpen(p),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.isReading
                                ? 'Saved reading'
                                : 'Roll ${p.roll!.number} · Frame ${p.frame!.label}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: g.ink,
                            ),
                          ),
                          Text(
                            [
                              if (p.roll case final r?) r.filmStock,
                              p.camera,
                            ].join(' · '),
                            style: TextStyle(fontSize: 14, color: g.secondary),
                          ),
                          if (_when(loc, p) case final w when w.isNotEmpty)
                            Text(
                              w,
                              style: TextStyle(
                                fontSize: 13,
                                color: g.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
