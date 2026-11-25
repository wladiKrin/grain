import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/theme.dart';
import '../version.dart';
import 'basemap.dart';

/// The bundled basemap (see `tool/basemap/`).
const basemapAsset = 'assets/map/basemap.bin';

Future<Basemap>? _bundled;

/// Reads and decodes the basemap from [bundle]; from the app's own bundle
/// it is read once per run, on first opening the map.
Future<Basemap> loadBasemap([AssetBundle? bundle]) {
  Future<Basemap> load(AssetBundle b) async {
    final data = await b.load(basemapAsset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    // About 100k points: decoded off the UI thread (the result is handed
    // back without a copy).
    return Isolate.run(() => Basemap.decode(bytes));
  }

  if (bundle != null) return load(bundle);
  return _bundled ??= load(rootBundle).catchError((Object e) {
    _bundled = null;
    throw e;
  });
}

/// Where the online tiles come from: OpenStreetMap's own servers, used as
/// their tile usage policy asks (an identifying User-Agent, visible
/// attribution, no prefetching).
const osmUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Names Grain and where it lives, as the OSM tile policy asks.
const osmUserAgent = 'Grain/$appVersion (+https://github.com/wladiKrin/grain)';

const osmAttribution = '© OpenStreetMap contributors';

/// A tile provider for [osmUrlTemplate]: a modest disk cache in the app's
/// cache directory, and failures (no network, network permission revoked)
/// shown as empty tiles over the offline layers, never as errors.
TileProvider osmTileProvider() => NetworkTileProvider(
  headers: {'User-Agent': osmUserAgent},
  silenceExceptions: true,
  cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: 50 * 1024 * 1024,
  ),
);

/// Water and the other basemap colours, from the Grain palette.
class MapColors {
  const MapColors({
    required this.water,
    required this.land,
    required this.coast,
    required this.border,
    required this.label,
    required this.capital,
  });

  factory MapColors.of(GrainPalette g, Brightness b) => MapColors(
    water: b == Brightness.dark
        ? const Color(0xFF1C2124)
        : const Color(0xFFDCE1E1),
    land: g.ground,
    coast: g.border,
    border: g.ink.withValues(alpha: .4),
    label: g.secondary,
    capital: g.ink,
  );

  final Color water, land, coast, border, label, capital;
}

/// The basemap's land, lakes and borders as flutter_map layers, built once
/// per basemap and palette.
class BasemapLayers {
  BasemapLayers(this.map, this.colors)
    : land = [
        for (final p in map.land)
          Polygon(
            points: p.outline,
            holePointsList: p.holes.isEmpty ? null : p.holes,
            color: colors.land,
            borderColor: colors.coast,
            borderStrokeWidth: .8,
          ),
      ],
      lakes = [
        for (final p in map.lakes)
          Polygon(
            points: p.outline,
            holePointsList: p.holes.isEmpty ? null : p.holes,
            color: colors.water,
            borderColor: colors.coast,
            borderStrokeWidth: .6,
          ),
      ],
      borders = [
        for (final l in map.borders)
          Polyline(points: l, color: colors.border, strokeWidth: .8),
      ];

  final Basemap map;
  final MapColors colors;
  final List<Polygon> land, lakes;
  final List<Polyline> borders;

  /// Bottom to top: land, lakes, borders, place names.
  List<Widget> get layers => [
    PolygonLayer(polygons: land, polygonLabels: false),
    PolygonLayer(polygons: lakes, polygonLabels: false),
    PolylineLayer(polylines: borders),
    PlaceLabels(places: map.places, colors: colors),
  ];
}

/// Place names for the camera's zoom, the most prominent first, leaving
/// out any that would overlap one already drawn.
class PlaceLabels extends StatelessWidget {
  const PlaceLabels({super.key, required this.places, required this.colors});

  final List<Place> places;
  final MapColors colors;

  /// Labels drawn at most, so a world view stays quick.
  static const maxLabels = 80;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _LabelPainter(camera, places, colors),
      ),
    );
  }
}

class _LabelPainter extends CustomPainter {
  _LabelPainter(this.camera, this.places, this.colors);

  final MapCamera camera;
  final List<Place> places;
  final MapColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = camera.zoom;
    final bounds = camera.visibleBounds;
    final taken = <Rect>[];
    final dot = Paint()..color = colors.label;
    for (final p in places) {
      if (taken.length >= PlaceLabels.maxLabels) break;
      if (p.minZoom > zoom) {
        // Sorted by min zoom: nothing later shows at this zoom either.
        break;
      }
      if (!bounds.contains(p.position)) continue;
      final at = camera.latLngToScreenOffset(p.position);
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
      final origin = at + Offset(5, -text.height / 2);
      final rect = (origin & text.size)
          .inflate(3)
          .expandToInclude(Rect.fromCircle(center: at, radius: 3));
      if (taken.any(rect.overlaps)) {
        text.dispose();
        continue;
      }
      taken.add(rect);
      canvas.drawCircle(at, p.capital ? 2.5 : 2, dot);
      text.paint(canvas, origin);
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_LabelPainter old) =>
      old.camera != camera || old.places != places || old.colors != colors;
}
