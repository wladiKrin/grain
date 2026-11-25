import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';

import '../gear/gear_controller.dart';
import '../gear/model.dart';
import '../rolls/roll_controller.dart';
import '../rolls/ui/frame_editor.dart';
import '../rolls/ui/reading_screen.dart';
import '../settings/settings.dart';
import '../ui/round_button.dart';
import '../ui/theme.dart';
import 'basemap.dart';
import 'map_layers.dart';
import 'map_points.dart';

/// The all-rolls map's filter: everything, saved readings only, or a roll.
const _allFilter = '';
const _readingsFilter = '\u0000readings';

/// Logged locations on a map: every located frame and saved reading, or
/// only the frames of [rollId]. The basemap is the bundled one; with the
/// online map setting on, OpenStreetMap tiles are drawn over it.
class MapScreen extends StatefulWidget {
  MapScreen({
    super.key,
    required this.rolls,
    required this.gear,
    required this.settings,
    this.rollId,
    Future<Basemap>? basemap,
    this.tileProvider = osmTileProvider,
  }) : basemap = basemap ?? loadBasemap();

  final RollController rolls;

  /// Bodies and lenses for the frame editor.
  final GearController gear;

  /// Whether OpenStreetMap tiles are shown ([Settings.onlineMap]).
  final Settings settings;

  /// Only this roll's frames; null shows every roll and the saved readings.
  final String? rollId;
  final Future<Basemap> basemap;

  /// Makes the online tile provider, once each time the tiles are turned on
  /// (tests pass one that never goes to the network).
  final TileProvider Function() tileProvider;

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
  Basemap? _basemap;
  BasemapLayers? _layers;

  @override
  void initState() {
    super.initState();
    widget.rolls.addListener(_load);
    widget.settings.addListener(_settingsChanged);
    widget.basemap.then(
      (b) {
        if (mounted) setState(() => _basemap = b);
      },
      onError: (Object _) {
        // No basemap: the markers still show on the water colour.
      },
    );
    _load();
  }

  @override
  void dispose() {
    widget.rolls.removeListener(_load);
    widget.settings.removeListener(_settingsChanged);
    _map.dispose();
    super.dispose();
  }

  void _settingsChanged() {
    if (mounted) setState(() {});
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

  CameraFit _fit(List<MapPoint> points) => CameraFit.coordinates(
    coordinates: [for (final p in points) p.position],
    padding: const EdgeInsets.fromLTRB(48, 48, 48, 160),
    maxZoom: 13,
  );

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

  BasemapLayers? _layersFor(Basemap? b, MapColors c) {
    if (b == null) return null;
    final l = _layers;
    if (l != null && l.map == b && l.colors.land == c.land) return l;
    return _layers = BasemapLayers(b, c);
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
    final layers = _layersFor(_basemap, colors);
    final online = widget.settings.onlineMap;
    if (!online) _tiles = null;
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
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) {
              if (_selected.isNotEmpty) setState(() => _selected = const []);
            },
          ),
          children: [
            ...?layers?.layers,
            if (online)
              TileLayer(
                urlTemplate: osmUrlTemplate,
                tileProvider: _tiles ??= widget.tileProvider(),
                maxNativeZoom: 19,
                // Only what is on screen: no tiles fetched ahead.
                panBuffer: 0,
                tileBuilder: brightness == Brightness.dark
                    ? darkModeTileBuilder
                    : null,
              ),
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
          left: 8,
          bottom: inset.bottom + 6,
          child: _Attribution(online ? osmAttribution : 'Natural Earth'),
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

  Iterable<MapPoint> _ordered(List<MapPoint> shown) => [
    for (final p in shown)
      if (p.isReading && !_selected.contains(p)) p,
    for (final p in shown)
      if (!p.isReading && !_selected.contains(p)) p,
    for (final p in shown)
      if (_selected.contains(p)) p,
  ];
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
