import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../gear/gear_controller.dart';
import '../gear/model.dart';
import '../rolls/roll_controller.dart';
import '../rolls/ui/frame_editor.dart';
import '../rolls/ui/reading_screen.dart';
import '../settings/settings.dart';
import '../ui/permissions.dart';
import '../ui/round_button.dart';
import '../ui/theme.dart';
import 'basemap_files.dart';
import 'geo.dart';
import 'map_markers.dart';
import 'map_network.dart';
import 'map_points.dart';
import 'map_style_sheet.dart';
import 'map_styles.dart';
import 'map_view.dart';
import 'maplibre_view.dart';

/// The all-rolls map's filter: everything, saved readings only, or a roll.
const _allFilter = '';
const _readingsFilter = '\u0000readings';

/// Logged locations on a map: every located frame and saved reading, or
/// only the frames of [rollId]. MapLibre draws it, in the style chosen in
/// [settings]: the bundled offline basemap, or an online one.
///
/// The same points show as a list too (the app bar's list button), newest
/// first: MapLibre draws the markers inside its own view, out of a screen
/// reader's reach, so the list is how TalkBack gets to them. With a screen
/// reader on, the screen opens on the list.
class MapScreen extends StatefulWidget {
  MapScreen({
    super.key,
    required this.rolls,
    required this.gear,
    required this.settings,
    this.rollId,
    Future<OfflineSources>? offline,
    MapNetwork? network,
    this.mapView = mapLibreView,
    this.openSettings = openAppSettings,
  }) : offline = offline ?? loadOfflineSources(),
       network = network ?? PlatformMapNetwork.instance;

  final RollController rolls;

  /// Bodies and lenses for the frame editor.
  final GearController gear;

  /// The map style ([Settings.mapStyle]).
  final Settings settings;

  /// Opened from the note shown when the online map does not load.
  final OpenSettings openSettings;

  /// Only this roll's frames; null shows every roll and the saved readings.
  final String? rollId;

  /// The offline basemap's files.
  final Future<OfflineSources> offline;

  /// The map's HTTP client: the User-Agent, Offline's no-network switch,
  /// and the requests that fail.
  final MapNetwork network;

  /// The map itself (tests pass a fake: MapLibre needs the platform).
  final MapViewBuilder mapView;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GrainPalette get g => context.grain;

  List<MapPoint>? _points;
  int _generation = 0;
  String _filter = _allFilter;

  /// The points show as a list, not on the map. Null until the screen
  /// first builds: then the list if a screen reader is on.
  bool? _asList;

  /// The marker tapped and the points under it, shown in the card.
  List<MapPoint> _selected = const [];

  OfflineSources? _offline;

  /// Done reading the offline basemap, and whether that failed (said over
  /// the map, not left blank).
  bool _offlineDone = false;
  bool _offlineFailed = false;

  /// The style the map shows: the one in the settings once the map's HTTP
  /// client is set for it (online or not), so that Offline never goes
  /// online, not even for a request of the style before.
  MapStyle? _style;
  int _configuring = 0;

  final _failures = MapFailures();
  StreamSubscription<MapRequest>? _requests;
  late final AppLifecycleListener _lifecycle;

  MapViewController? _map;
  CameraView? _initialCamera;
  Size _size = Size.zero;

  /// The markers last built, and what from.
  Map<String, Object?>? _markers;
  List<MapPoint>? _markersShown;
  Set<String>? _markersSelected;
  GrainPalette? _markersPalette;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _retry);
    widget.rolls.addListener(_load);
    widget.settings.addListener(_settingsChanged);
    _failures.addListener(_failuresChanged);
    _requests = widget.network.requests.listen(_failures.request);
    widget.offline.then(
      (o) {
        if (mounted) {
          setState(() {
            _offline = o;
            _offlineDone = true;
          });
        }
      },
      onError: (Object e) {
        debugPrint('Offline map not loaded: $e');
        // No basemap: the markers still show on the water colour, with a
        // note saying why.
        if (mounted) {
          setState(() {
            _offlineFailed = true;
            _offlineDone = true;
          });
        }
      },
    );
    _configure();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decided once: a screen reader turned on later does not swap the
    // view under the user.
    _asList ??= MediaQuery.accessibleNavigationOf(context);
  }

  @override
  void dispose() {
    widget.rolls.removeListener(_load);
    widget.settings.removeListener(_settingsChanged);
    _failures
      ..removeListener(_failuresChanged)
      ..dispose();
    unawaited(_requests?.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  void _failuresChanged() {
    if (mounted) setState(() {});
  }

  void _settingsChanged() {
    if (mounted && widget.settings.mapStyle != _style) _configure();
  }

  /// Sets the map's HTTP client for the style in the settings, then shows
  /// that style.
  void _configure() {
    final style = widget.settings.mapStyle;
    final call = ++_configuring;
    unawaited(
      widget.network
          .configure(userAgent: osmUserAgent, offline: !style.online)
          .catchError((Object e) => debugPrint('Map client not set: $e'))
          .whenComplete(() {
            if (!mounted || call != _configuring) return;
            setState(() => _style = style);
          }),
    );
  }

  /// Asks for the map again if it failed: the network may be back, or
  /// allowed in the system settings.
  void _retry() {
    if (!mounted || !_failures.failing) return;
    unawaited(_map?.reload());
  }

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

  /// All of [points] in view above the card, at most zoom 13.
  CameraView _fit(List<MapPoint> points, Size size) => fitCamera(
    [for (final p in points) p.position],
    width: size.width,
    height: size.height,
  );

  void _recentre() {
    final shown = _shown;
    if (shown.isNotEmpty) unawaited(_map?.moveTo(_fit(shown, _size)));
  }

  void _setFilter(String f) {
    setState(() {
      _filter = f;
      _selected = const [];
    });
    _recentre();
  }

  Future<void> _tapMarker(String id) async {
    final camera = await _map?.camera();
    if (!mounted) return;
    final shown = _shown;
    final p = shown.where((q) => q.id == id).firstOrNull;
    if (p == null) return;
    final zoom = camera?.zoom ?? _initialCamera?.zoom ?? 13;
    setState(() => _selected = pointsNear(p, shown, zoom));
  }

  /// Between the map and the list. The map goes when the list shows; back
  /// on the map, it opens fitted to the points shown then.
  void _toggleList() {
    setState(() {
      _asList = !(_asList ?? false);
      _selected = const [];
      if (_asList!) {
        _map = null;
        _initialCamera = null;
      }
    });
  }

  void _tapMap() {
    if (_selected.isNotEmpty) setState(() => _selected = const []);
  }

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

  /// The markers' GeoJSON, built again only when what it shows changes.
  Map<String, Object?> _markersFor(List<MapPoint> shown) {
    final selected = {for (final p in _selected) p.id};
    if (_markers case final m?
        when listEquals(_markersShown, shown) &&
            setEquals(_markersSelected, selected) &&
            _markersPalette == g) {
      return m;
    }
    _markersShown = shown;
    _markersSelected = selected;
    _markersPalette = g;
    return _markers = markerGeoJson(shown, selected, g);
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final filters = points == null
        ? const <String, String>{}
        : _filters(points);
    final asList = _asList ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (points != null && points.isNotEmpty)
            IconButton(
              tooltip: asList ? 'Show as map' : 'Show as list',
              icon: Icon(asList ? Icons.map_outlined : Icons.list),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: _toggleList,
            ),
          if (points != null && points.isNotEmpty && !asList)
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
          : asList
          ? _listView()
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

  /// The points shown, newest first; a row opens what a marker's card does.
  Widget _listView() {
    final shown = [..._shown]..sort(newestFirst);
    final inset = MediaQuery.paddingOf(context);
    return ListView.separated(
      padding: EdgeInsets.only(top: 4, bottom: inset.bottom + 8),
      itemCount: shown.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, thickness: 1, color: g.border),
      itemBuilder: (_, i) => _PointRow(
        point: shown[i],
        onOpen: _open,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      ),
    );
  }

  Widget _mapView() {
    final brightness = Theme.of(context).brightness;
    final colors = MapColors.of(g, brightness);
    final style = _style;
    if (style == null || !_offlineDone) {
      return ColoredBox(color: colors.water, child: const SizedBox.expand());
    }
    final doc = mapStyleFor(style, brightness, colors, _offline);
    _failures.watch(doc);
    final shown = _shown;
    final inset = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              _size = box.biggest;
              final camera = _initialCamera ??= _fit(shown, _size);
              // The markers inside are out of a screen reader's reach: the
              // map says what it holds, and the list has them one by one.
              return Semantics(
                container: true,
                label: shown.length == 1
                    ? 'Map with 1 point'
                    : 'Map with ${shown.length} points',
                child: widget.mapView(
                  MapViewOptions(
                    style: doc,
                    initialCamera: camera,
                    markers: _markersFor(shown),
                    background: colors.water,
                    onMarkerTap: (id) => unawaited(_tapMarker(id)),
                    onMapTap: _tapMap,
                    onCreated: (c) => _map = c,
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Column(
            spacing: 8,
            children: [
              if (_offlineFailed && style == MapStyle.offline)
                Center(
                  child: _Attribution(
                    'The offline map could not be loaded: only the markers '
                    'show.',
                  ),
                ),
              if (doc.online && _failures.showing)
                _TilesNote(
                  onOpenSettings: widget.openSettings,
                  onDismiss: _failures.dismiss,
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
            child: _Attribution(doc.attribution),
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

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
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
                for (final p in points) _PointRow(point: p, onOpen: onOpen),
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

/// A point as the card and the list show it: "Roll N · Frame M" or "Saved
/// reading", film and camera, then the date and time where it was taken.
/// A tap opens the frame editor or the reading.
class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.point,
    required this.onOpen,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 8, 8),
  });

  final MapPoint point;
  final void Function(MapPoint p) onOpen;
  final EdgeInsets padding;

  String _when(MaterialLocalizations loc) {
    final t = point.takenAt;
    if (t == null) return '';
    final w = t.toUtc().add(Duration(minutes: point.utcOffsetMinutes));
    return '${loc.formatShortDate(w)} · '
        '${loc.formatTimeOfDay(TimeOfDay(hour: w.hour, minute: w.minute), alwaysUse24HourFormat: true)}';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    final p = point;
    final when = _when(MaterialLocalizations.of(context));
    return InkWell(
      onTap: () => onOpen(p),
      child: Padding(
        padding: padding,
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
              [if (p.roll case final r?) r.filmStock, p.camera].join(' · '),
              style: TextStyle(fontSize: 14, color: g.secondary),
            ),
            if (when.isNotEmpty)
              Text(when, style: TextStyle(fontSize: 13, color: g.secondary)),
          ],
        ),
      ),
    );
  }
}
