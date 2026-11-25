import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../settings/settings.dart';
import '../ui/theme.dart';
import '../version.dart';
import 'basemap.dart';
import 'basemap_geometry.dart';
import 'tile_loading.dart';
import 'vector_map.dart';

/// The bundled basemap (see `tool/basemap/`).
const basemapAsset = 'assets/map/basemap.bin';

Future<Basemap>? _bundled;

final _geometries = Expando<BasemapGeometry>('basemap geometry');

/// [map] projected for drawing: built with it by [loadBasemap], otherwise
/// (a basemap from elsewhere, as in tests) built here, once.
BasemapGeometry basemapGeometry(Basemap map) =>
    _geometries[map] ??= BasemapGeometry.build(map);

/// Reads and decodes the basemap from [bundle]; from the app's own bundle
/// it is read once per run, on first opening the map.
Future<Basemap> loadBasemap([AssetBundle? bundle]) {
  Future<Basemap> load(AssetBundle b) async {
    final data = await b.load(basemapAsset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    // About 100k points: decoded, projected and cut into levels of detail
    // off the UI thread (the result is handed back without a copy).
    final (map, geometry) = await Isolate.run(() {
      final m = Basemap.decode(bytes);
      return (m, BasemapGeometry.build(m));
    });
    _geometries[map] = geometry;
    return map;
  }

  if (bundle != null) return load(bundle);
  return _bundled ??= load(rootBundle).catchError((Object e) {
    _bundled = null;
    throw e;
  });
}

/// Names Grain and where it lives, as the tile servers' usage policies ask.
const osmUserAgent = 'Grain/$appVersion (+https://github.com/wladiKrin/grain)';

const osmAttribution = '© OpenStreetMap contributors';
const topoAttribution =
    '© OpenStreetMap contributors, SRTM · © OpenTopoMap (CC-BY-SA)';

/// The attribution of the bundled basemap.
const naturalEarthAttribution = 'Natural Earth';

/// What an online [MapStyle] draws over the basemap: raster tiles
/// ([OnlineTiles]) or a vector style drawn in the app ([VectorMap]).
sealed class OnlineMap {
  const OnlineMap();

  /// What the map has to credit, shown on it.
  String get attribution;

  /// The online map for [style] in [brightness]; null for
  /// [MapStyle.offline].
  static OnlineMap? of(MapStyle style, Brightness brightness) =>
      VectorMap.of(style, brightness) ?? OnlineTiles.of(style, brightness);
}

/// An OpenFreeMap vector style: Streets is Liberty, Minimal is Positron
/// in the light palette and OpenFreeMap's Dark in the dark one.
class VectorMap extends OnlineMap {
  const VectorMap(this.style);

  /// The vector style for [style] in [brightness]; null for the others.
  static VectorMap? of(MapStyle style, Brightness brightness) =>
      switch (style) {
        MapStyle.streets => const VectorMap(OpenFreeMapStyle.liberty),
        MapStyle.minimal => VectorMap(
          brightness == Brightness.dark
              ? OpenFreeMapStyle.dark
              : OpenFreeMapStyle.positron,
        ),
        _ => null,
      };

  final OpenFreeMapStyle style;

  @override
  String get attribution => openFreeMapAttribution;

  @override
  bool operator ==(Object other) => other is VectorMap && other.style == style;

  @override
  int get hashCode => style.hashCode;
}

/// Where an online raster [MapStyle]'s tiles come from and how they are
/// drawn. Each server is used as its usage policy asks: an identifying
/// User-Agent, visible attribution, nothing fetched ahead, at most two
/// connections at a time, and no zoom asked for past its own (closer in,
/// its tiles are scaled up).
class OnlineTiles extends OnlineMap {
  const OnlineTiles({
    required this.urlTemplate,
    required this.attribution,
    required this.maxNativeZoom,
    this.subdomains = const [],
    this.retina = false,
    this.colorFilter,
  });

  /// The tiles for [style] in [brightness]; null for [MapStyle.offline]
  /// and the vector styles.
  static OnlineTiles? of(MapStyle style, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (style) {
      MapStyle.offline || MapStyle.streets || MapStyle.minimal => null,
      MapStyle.muted => OnlineTiles(
        urlTemplate: osmUrlTemplate,
        maxNativeZoom: 19,
        attribution: osmAttribution,
        colorFilter: dark ? mutedDarkFilter : mutedLightFilter,
      ),
      MapStyle.standard => const OnlineTiles(
        urlTemplate: osmUrlTemplate,
        maxNativeZoom: 19,
        attribution: osmAttribution,
      ),
      MapStyle.topographic => const OnlineTiles(
        urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
        subdomains: ['a', 'b', 'c'],
        maxNativeZoom: 17,
        attribution: topoAttribution,
      ),
    };
  }

  final String urlTemplate;
  final List<String> subdomains;

  /// Whether the server has high-density tiles (`{r}` in the template),
  /// asked for on a high-density screen.
  final bool retina;
  final int maxNativeZoom;
  @override
  final String attribution;

  /// Drawn over the whole tile layer; null: the tiles as served.
  final ColorFilter? colorFilter;

  /// OpenStreetMap's own servers (no subdomains, as their policy asks).
  static const osmUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Rec. 709 luma weights.
  static const _r = .2126, _g = .7152, _b = .0722;

  /// OSM in soft grey: luma at 60 % contrast, lifted towards the paper,
  /// a touch warm.
  static const mutedLightFilter = ColorFilter.matrix([
    .6 * _r, .6 * _g, .6 * _b, 0, 98, //
    .6 * _r, .6 * _g, .6 * _b, 0, 95, //
    .6 * _r, .6 * _g, .6 * _b, 0, 90, //
    0, 0, 0, 1, 0, //
  ]);

  /// The dark palette's version: luma inverted at 55 % contrast, so white
  /// land turns a warm near-black and black text a light grey.
  static const mutedDarkFilter = ColorFilter.matrix([
    -.55 * _r, -.55 * _g, -.55 * _b, 0, 190, //
    -.55 * _r, -.55 * _g, -.55 * _b, 0, 186, //
    -.55 * _r, -.55 * _g, -.55 * _b, 0, 182, //
    0, 0, 0, 1, 0, //
  ]);
}

/// The tile provider for every online raster style ([GrainTileProvider]):
/// at most two connections to a server, failed loads tried again, and a
/// modest disk cache in the app's cache directory. A tile that fails to
/// load (no network, the network permission off) is reported to the tile
/// layer's error callback and draws nothing, leaving the offline layers
/// under it in view.
TileProvider onlineTileProvider() => GrainTileProvider(
  fetcher: TileFetcher(userAgent: osmUserAgent),
  ownsFetcher: true,
  cache: BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: 50 * 1024 * 1024,
  ),
);

/// The vector styles' tiles on disk at most (the raster tiles keep 50 MB
/// of their own).
const vectorCacheBytes = 40 * 1024 * 1024;

VectorStyleSource? _openFreeMap;

/// OpenFreeMap, one for the run (each style is read once): four
/// connections at most, as OpenFreeMap asks of apps.
VectorStyleSource openFreeMap() => _openFreeMap ??= OpenFreeMap(
  fetcher: TileFetcher(userAgent: osmUserAgent, connectionsPerHost: 4),
  cacheRoot: getApplicationCacheDirectory,
);

/// Water and the other basemap colours, from the Grain palette: the paper
/// ground as land on a slate sea in light mode, warm grey land on a near
/// black sea in dark mode.
class MapColors {
  const MapColors({
    required this.water,
    required this.land,
    required this.coast,
    required this.border,
    required this.label,
    required this.capital,
  });

  factory MapColors.of(GrainPalette g, Brightness b) => b == Brightness.dark
      ? MapColors(
          water: const Color(0xFF0E1417),
          land: const Color(0xFF302D29),
          coast: const Color(0xFF5A554E),
          border: const Color(0xFF6E685F).withValues(alpha: .6),
          label: g.secondary,
          capital: g.ink,
        )
      : MapColors(
          water: const Color(0xFFC5D0D2),
          land: g.ground,
          coast: const Color(0xFF9A9286),
          border: const Color(0xFF8F887C).withValues(alpha: .7),
          label: g.secondary,
          capital: g.ink,
        );

  final Color water, land, coast, border, label, capital;

  @override
  bool operator ==(Object other) =>
      other is MapColors &&
      other.water == water &&
      other.land == land &&
      other.coast == coast &&
      other.border == border &&
      other.label == label &&
      other.capital == capital;

  @override
  int get hashCode => Object.hash(water, land, coast, border, label, capital);
}

/// The basemap layers, bottom to top: land, lakes, shores and borders in
/// one layer, then the place names.
List<Widget> basemapLayers(Basemap map, MapColors colors) {
  final geometry = basemapGeometry(map);
  return [
    BasemapLayer(geometry: geometry, colors: colors),
    PlaceLabels(places: map.places, geometry: geometry, colors: colors),
  ];
}

/// Land, lakes, shores and borders, drawn from paths built once per cell:
/// a frame only moves and scales the canvas to the camera.
class BasemapLayer extends StatelessWidget {
  const BasemapLayer({super.key, required this.geometry, required this.colors});

  final BasemapGeometry geometry;
  final MapColors colors;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: BasemapPainter(camera, geometry, colors),
        ),
      ),
    );
  }
}

/// A cell's paths, built the first time it is on screen.
class _CellPaths {
  _CellPaths(BasemapCell c)
    : land = _path(c.land, close: true),
      lakes = _path(c.lakes, close: true),
      coast = _path(c.coast, close: false),
      borders = _path(c.borders, close: false);

  final ui.Path? land, lakes, coast, borders;

  static ui.Path? _path(Rings r, {required bool close}) {
    if (r.count == 0) return null;
    BasemapPainter.pathBuilds++;
    final p = ui.Path()..fillType = ui.PathFillType.evenOdd;
    final xy = r.xy, starts = r.starts;
    for (var k = 0; k < r.count; k++) {
      final a = starts[k], b = starts[k + 1];
      p.moveTo(xy[2 * a], xy[2 * a + 1]);
      for (var i = a + 1; i < b; i++) {
        p.lineTo(xy[2 * i], xy[2 * i + 1]);
      }
      if (close) p.close();
    }
    return p;
  }
}

final _cellPaths = Expando<_CellPaths>('basemap cell paths');

/// Draws a [BasemapGeometry] level for [camera]: per cell on screen, a
/// translate, a scale and its paths; no point is touched.
class BasemapPainter extends CustomPainter {
  BasemapPainter(this.camera, this.geometry, this.colors);

  final MapCamera camera;
  final BasemapGeometry geometry;
  final MapColors colors;

  /// Paths built so far, over all basemaps: each cell's once.
  @visibleForTesting
  static int pathBuilds = 0;

  /// Line widths on screen, in logical pixels.
  static const coastWidth = 1.0, borderWidth = .8;

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = camera.zoom;
    if (!zoom.isFinite) return;
    final s = math.pow(2, zoom).toDouble();
    final o = camera.pixelOrigin;
    final level = geometry.levelFor(zoom);
    // The visible world, and the copies of it east and west that show.
    final l = o.dx / s, t = o.dy / s;
    final r = (o.dx + size.width) / s, b = (o.dy + size.height) / s;
    final k0 = (l / worldSize).floor();
    final k1 = math.min((r / worldSize).floor(), k0 + 3);
    final visible = <(BasemapCell, double)>[];
    for (var k = k0; k <= k1; k++) {
      final dx = k * worldSize;
      for (final c in level.cells) {
        if (c.overlaps(l - dx, t, r - dx, b)) visible.add((c, dx));
      }
    }
    if (visible.isEmpty) return;

    // A level in one cell has anti-aliased fills. Cut into cells, it has
    // not, so no seam shows where cells meet (the shore is drawn over the
    // edge of the land anyway).
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = level.cells.length == 1;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.bevel
      ..strokeCap = StrokeCap.round;

    void pass(ui.Path? Function(_CellPaths p) pick, Paint paint) {
      for (final (c, dx) in visible) {
        final path = pick(_cellPaths[c] ??= _CellPaths(c));
        if (path == null) continue;
        canvas
          ..save()
          ..translate((c.anchorX + dx) * s - o.dx, c.anchorY * s - o.dy)
          ..scale(s)
          ..drawPath(path, paint)
          ..restore();
      }
    }

    pass((p) => p.land, fill..color = colors.land);
    pass((p) => p.lakes, fill..color = colors.water);
    pass(
      (p) => p.coast,
      stroke
        ..color = colors.coast
        ..strokeWidth = coastWidth / s,
    );
    pass(
      (p) => p.borders,
      stroke
        ..color = colors.border
        ..strokeWidth = borderWidth / s,
    );
  }

  @override
  bool shouldRepaint(BasemapPainter old) =>
      old.camera != camera || old.geometry != geometry || old.colors != colors;
}

/// Place names for the camera's zoom, the most prominent first, leaving
/// out any that would overlap one already drawn.
class PlaceLabels extends StatefulWidget {
  const PlaceLabels({
    super.key,
    required this.places,
    required this.geometry,
    required this.colors,
  });

  final List<Place> places;

  /// For the places' world positions.
  final BasemapGeometry geometry;
  final MapColors colors;

  /// Labels drawn at most, so a world view stays quick.
  static const maxLabels = 80;

  @override
  State<PlaceLabels> createState() => _PlaceLabelsState();
}

class _PlaceLabelsState extends State<PlaceLabels> {
  final _cache = LabelCache();

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _LabelPainter(camera, widget, _cache),
        ),
      ),
    );
  }
}

/// Laid-out place names, kept across frames: a pan or zoom only paints
/// them. Past [capacity], the least recently drawn go; all go when the
/// colours change.
class LabelCache {
  LabelCache({this.capacity = 400});

  final int capacity;
  final _painters = <int, TextPainter>{};
  MapColors? _colors;

  /// Labels laid out so far.
  @visibleForTesting
  int layouts = 0;

  /// Labels laid out so far by every cache.
  @visibleForTesting
  static int totalLayouts = 0;

  int get length => _painters.length;

  /// The label of place [index], laid out once.
  TextPainter painter(int index, Place p, MapColors colors) {
    if (colors != _colors) {
      _clear();
      _colors = colors;
    }
    final hit = _painters.remove(index);
    if (hit != null) return _painters[index] = hit;
    layouts++;
    totalLayouts++;
    final text = TextPainter(
      text: TextSpan(
        text: p.name,
        style: TextStyle(
          fontFamily: grainFont,
          fontSize: p.capital ? 12 : 11,
          fontWeight: p.capital ? FontWeight.w600 : FontWeight.w400,
          color: p.capital ? colors.capital : colors.label,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (_painters.length >= capacity) {
      _painters.remove(_painters.keys.first)?.dispose();
    }
    return _painters[index] = text;
  }

  void _clear() {
    for (final t in _painters.values) {
      t.dispose();
    }
    _painters.clear();
  }

  void dispose() => _clear();
}

class _LabelPainter extends CustomPainter {
  _LabelPainter(this.camera, this.labels, this.cache);

  final MapCamera camera;
  final PlaceLabels labels;
  final LabelCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = camera.zoom;
    if (!zoom.isFinite) return;
    final s = math.pow(2, zoom).toDouble();
    final o = camera.pixelOrigin;
    final colors = labels.colors;
    final places = labels.places;
    final xy = labels.geometry.placeXY;
    final ws = worldSize * s;
    final k0 = (o.dx / ws).floor();
    final k1 = math.min(((o.dx + size.width) / ws).floor(), k0 + 3);
    final screen = Offset.zero & size;
    final taken = <Rect>[];
    final dot = Paint()..color = colors.label;
    final n = math.min(places.length, xy.length ~/ 2);
    for (var i = 0; i < n; i++) {
      if (taken.length >= PlaceLabels.maxLabels) break;
      final p = places[i];
      // Sorted by min zoom: nothing later shows at this zoom either.
      if (p.minZoom > zoom) break;
      final y = xy[2 * i + 1] * s - o.dy;
      if (y < 0 || y > size.height) continue;
      for (var k = k0; k <= k1; k++) {
        final at = Offset(xy[2 * i] * s + k * ws - o.dx, y);
        if (!screen.contains(at)) continue;
        final text = cache.painter(i, p, colors);
        final origin = at + Offset(5, -text.height / 2);
        final rect = (origin & text.size)
            .inflate(3)
            .expandToInclude(Rect.fromCircle(center: at, radius: 3));
        if (taken.any(rect.overlaps)) continue;
        taken.add(rect);
        canvas.drawCircle(at, p.capital ? 2.5 : 2, dot);
        text.paint(canvas, origin);
      }
    }
  }

  @override
  bool shouldRepaint(_LabelPainter old) =>
      old.camera != camera ||
      old.labels.places != labels.places ||
      old.labels.colors != labels.colors ||
      old.cache != cache;
}
