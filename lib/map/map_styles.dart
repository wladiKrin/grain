import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../settings/settings.dart';
import '../ui/theme.dart';
import '../version.dart';
import 'glyphs.dart';
import 'openfreemap_dark.g.dart';

export 'glyphs.dart';

/// Names Grain and where it lives, as the tile servers' usage policies ask.
/// Sent with every map request (see `MapNetPlugin.kt`).
const osmUserAgent = 'Grain/$appVersion (+https://github.com/wladiKrin/grain)';

const osmAttribution = '© OpenStreetMap contributors';
const topoAttribution =
    '© OpenStreetMap contributors, SRTM · © OpenTopoMap (CC-BY-SA)';

/// What OpenFreeMap asks a client to show.
const openFreeMapAttribution =
    'OpenFreeMap © OpenMapTiles Data from OpenStreetMap';

/// The attribution of the bundled basemap.
const naturalEarthAttribution = 'Natural Earth';

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

/// [c] as a style colour, `rgba(r, g, b, a)`.
String cssColor(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  final a = (c.a * 1000).round() / 1000;
  return 'rgba(${ch(c.r)}, ${ch(c.g)}, ${ch(c.b)}, $a)';
}

/// Where the offline basemap's GeoJSON is, by layer (`file://` URLs in the
/// app's cache directory), and the zooms its places are labelled from.
class OfflineSources {
  const OfflineSources({required this.data, required this.placeZooms});

  final Map<String, String> data;
  final List<int> placeZooms;
}

/// The OpenFreeMap styles Grain draws (https://openfreemap.org: free, no
/// key, OpenStreetMap data in the OpenMapTiles schema), drawn by MapLibre
/// as OpenFreeMap serves them.
enum OpenFreeMapStyle {
  /// Streets, the Google-like one.
  liberty,

  /// Minimal in the light palette.
  positron,

  /// Minimal in the dark palette.
  dark;

  String get url => 'https://tiles.openfreemap.org/styles/$name';

  /// The style for [style] in [brightness]; null for the raster styles and
  /// Offline.
  static OpenFreeMapStyle? of(MapStyle style, Brightness brightness) =>
      switch (style) {
        MapStyle.streets => liberty,
        MapStyle.minimal => brightness == Brightness.dark ? dark : positron,
        _ => null,
      };
}

/// An online raster style's tiles and how they are drawn. Each server is
/// used as its usage policy asks: an identifying User-Agent, visible
/// attribution, at most two connections at a time (`MapNetPlugin.kt`), and
/// no zoom asked for past its own (closer in, its tiles are scaled up).
class RasterTiles {
  const RasterTiles({
    required this.tiles,
    required this.attribution,
    required this.maxZoom,
    this.paint = const {},
  });

  /// The tiles for [style] in [brightness]; null for Offline and the
  /// vector styles.
  static RasterTiles? of(MapStyle style, Brightness brightness) =>
      switch (style) {
        MapStyle.offline || MapStyle.streets || MapStyle.minimal => null,
        MapStyle.muted => RasterTiles(
          tiles: const [osmTiles],
          maxZoom: 19,
          attribution: osmAttribution,
          paint: brightness == Brightness.dark ? mutedDark : mutedLight,
        ),
        MapStyle.standard => const RasterTiles(
          tiles: [osmTiles],
          maxZoom: 19,
          attribution: osmAttribution,
        ),
        MapStyle.topographic => const RasterTiles(
          tiles: [
            'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
            'https://b.tile.opentopomap.org/{z}/{x}/{y}.png',
            'https://c.tile.opentopomap.org/{z}/{x}/{y}.png',
          ],
          maxZoom: 17,
          attribution: topoAttribution,
        ),
      };

  /// URL templates, `{z}/{x}/{y}`; MapLibre spreads the requests over them.
  final List<String> tiles;
  final String attribution;

  /// The deepest zoom the server has.
  final int maxZoom;

  /// The raster layer's paint properties.
  final Map<String, Object> paint;

  /// The tiles are 256 pixels: drawn at the size the server means.
  static const tileSize = 256;

  /// OpenStreetMap's own servers (one host, as their policy asks).
  static const osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// OSM in soft grey: no colour, and the tones squeezed towards the paper
  /// (white land stays light, black text a mid grey).
  static const mutedLight = <String, Object>{
    'raster-saturation': -1.0,
    'raster-contrast': -0.15,
    'raster-brightness-min': 0.4,
    'raster-brightness-max': 0.95,
  };

  /// The dark palette's version: the tones inverted (brightness-min above
  /// max), so white land turns a near-black and black text a light grey.
  static const mutedDark = <String, Object>{
    'raster-saturation': -1.0,
    'raster-contrast': -0.1,
    'raster-brightness-min': 0.72,
    'raster-brightness-max': 0.2,
  };

  /// The hosts the tiles come from.
  Set<String> get hosts => {for (final t in tiles) Uri.parse(t).host};
}

/// A map style ready for MapLibre: [style] is a style URL or the style
/// JSON itself.
class MapStyleDoc {
  const MapStyleDoc({
    required this.style,
    required this.attribution,
    this.hosts = const {},
  });

  final String style;
  final String attribution;

  /// The servers the style loads from; none for Offline.
  final Set<String> hosts;

  bool get online => hosts.isNotEmpty;

  /// The style URL, if [style] is one; null for a style written here.
  String? get url => style.startsWith('https://') ? style : null;

  @override
  bool operator ==(Object other) =>
      other is MapStyleDoc &&
      other.style == style &&
      other.attribution == attribution;

  @override
  int get hashCode => Object.hash(style, attribution);
}

/// The style for [style] in [brightness]. Offline is written here from the
/// bundled basemap ([offline]; null if it could not be read: water only);
/// the raster styles draw their tiles over it, the OpenFreeMap styles are
/// their own.
MapStyleDoc mapStyleFor(
  MapStyle style,
  Brightness brightness,
  MapColors colors,
  OfflineSources? offline,
) {
  if (OpenFreeMapStyle.of(style, brightness) case final s?) {
    if (s == OpenFreeMapStyle.dark) {
      return MapStyleDoc(
        style: minimalDarkStyle,
        attribution: openFreeMapAttribution,
        hosts: {Uri.parse(s.url).host},
      );
    }
    return MapStyleDoc(
      style: s.url,
      attribution: openFreeMapAttribution,
      hosts: {Uri.parse(s.url).host},
    );
  }
  if (RasterTiles.of(style, brightness) case final r?) {
    return MapStyleDoc(
      style: jsonEncode(rasterStyle(r, colors, offline)),
      attribution: r.attribution,
      hosts: r.hosts,
    );
  }
  return MapStyleDoc(
    style: jsonEncode(offlineStyle(colors, offline)),
    attribution: naturalEarthAttribution,
  );
}

/// The Offline style: Natural Earth land, lakes, shores, borders and place
/// names from [offline], on the water colour. Nothing in it is online.
Map<String, Object?> offlineStyle(MapColors colors, OfflineSources? offline) =>
    {
      'version': 8,
      'name': 'Grain Offline',
      if (offline != null) 'glyphs': glyphsUrl,
      'sources': _basemapSources(offline),
      'layers': [
        ..._basemapLayers(colors, offline),
        if (offline != null) ..._placeLayers(colors, offline),
      ],
    };

/// [tiles] over the offline land and lakes, which show where tiles have
/// not loaded (yet, or with no network).
Map<String, Object?> rasterStyle(
  RasterTiles tiles,
  MapColors colors,
  OfflineSources? offline,
) => {
  'version': 8,
  'name': 'Grain raster',
  'sources': {
    ..._basemapSources(offline),
    'raster': {
      'type': 'raster',
      'tiles': tiles.tiles,
      'tileSize': RasterTiles.tileSize,
      'maxzoom': tiles.maxZoom,
      'attribution': tiles.attribution,
    },
  },
  'layers': [
    ..._basemapLayers(colors, offline),
    {
      'id': 'raster',
      'type': 'raster',
      'source': 'raster',
      if (tiles.paint.isNotEmpty) 'paint': tiles.paint,
    },
  ],
};

/// The basemap's GeoJSON is cut into tiles down to this zoom; closer in,
/// they are scaled (the data is 1:50m).
const _basemapMaxZoom = 10;

Map<String, Object?> _basemapSources(OfflineSources? offline) => {
  if (offline != null)
    for (final e in offline.data.entries)
      e.key: {
        'type': 'geojson',
        'data': e.value,
        if (e.key != 'places') 'maxzoom': _basemapMaxZoom,
        'attribution': naturalEarthAttribution,
      },
};

/// Line widths on screen, in logical pixels.
const coastWidth = 1.0, borderWidth = .8;

List<Map<String, Object?>> _basemapLayers(
  MapColors colors,
  OfflineSources? offline,
) => [
  {
    'id': 'water',
    'type': 'background',
    'paint': {'background-color': cssColor(colors.water)},
  },
  if (offline != null) ...[
    {
      'id': 'land',
      'type': 'fill',
      'source': 'land',
      'paint': {'fill-color': cssColor(colors.land), 'fill-antialias': false},
    },
    {
      'id': 'lakes',
      'type': 'fill',
      'source': 'lakes',
      'paint': {'fill-color': cssColor(colors.water), 'fill-antialias': false},
    },
    {
      'id': 'coast',
      'type': 'line',
      'source': 'coast',
      'layout': {'line-join': 'bevel', 'line-cap': 'round'},
      'paint': {'line-color': cssColor(colors.coast), 'line-width': coastWidth},
    },
    {
      'id': 'borders',
      'type': 'line',
      'source': 'borders',
      'layout': {'line-join': 'bevel', 'line-cap': 'round'},
      'paint': {
        'line-color': cssColor(colors.border),
        'line-width': borderWidth,
      },
    },
  ],
];

/// One label layer per zoom a place shows from, the most prominent on top
/// (MapLibre places the top layer's labels first, and leaves out any that
/// would overlap). A label is a dot (the bullet, so it goes with its name)
/// and the name to its right; capitals bold and darker.
List<Map<String, Object?>> _placeLayers(
  MapColors colors,
  OfflineSources offline,
) => [
  for (final z in offline.placeZooms.reversed)
    {
      'id': 'places-$z',
      'type': 'symbol',
      'source': 'places',
      'minzoom': z,
      'filter': [
        '==',
        ['get', 'z'],
        z,
      ],
      'layout': {
        'text-field': [
          'concat',
          '•  ',
          ['get', 'name'],
        ],
        'text-font': [
          'case',
          ['get', 'capital'],
          [
            'literal',
            [boldFont],
          ],
          [
            'literal',
            [regularFont],
          ],
        ],
        'text-size': [
          'case',
          ['get', 'capital'],
          12,
          11,
        ],
        'text-anchor': 'left',
        'text-justify': 'left',
        'text-offset': [-.25, 0],
        'text-max-width': 30,
        'text-padding': 3,
        'symbol-sort-key': ['get', 'rank'],
      },
      'paint': {
        'text-color': [
          'case',
          ['get', 'capital'],
          cssColor(colors.capital),
          cssColor(colors.label),
        ],
        'text-halo-color': cssColor(colors.land),
        'text-halo-width': 1.2,
      },
    },
];

/// Every URL [style] (style JSON) loads from: its sources' data and tiles,
/// glyphs and sprite.
Iterable<String> styleUrls(Map<String, Object?> style) sync* {
  for (final k in ['glyphs', 'sprite']) {
    if (style[k] case final String s) yield s;
  }
  final sources = style['sources'] as Map? ?? const {};
  for (final s in sources.values.cast<Map<String, Object?>>()) {
    if (s['url'] case final String u) yield u;
    if (s['data'] case final String d) yield d;
    if (s['tiles'] case final List<Object?> t) yield* t.cast<String>();
  }
}

/// Minimal in dark mode: OpenFreeMap's Dark style (bundled,
/// `tool/map/fetch_dark.dart`) with [strongerDark] applied. As served, its
/// labels and roads are barely lighter than the ground.
final String minimalDarkStyle = jsonEncode(
  strongerDark(jsonDecode(openFreeMapDarkJson) as Map<String, Object?>),
);

/// Paint colours [strongerDark] puts on OpenFreeMap Dark's layers, by layer
/// id: warm greys from the Grain dark palette, a darker blue-black sea,
/// brighter roads and borders, and labels near the palette's ink.
final darkPaint = <String, Map<String, Object>>{
  'background': {'background-color': '#1B1A18'},
  'water': {'fill-color': '#080B0D'},
  'waterway': {'line-color': '#080B0D'},
  'landcover_ice_shelf': {'fill-color': '#232526'},
  'landcover_glacier': {'fill-color': '#232526'},
  'landuse_residential': {'fill-color': '#211F1C'},
  'landcover_wood': {'fill-color': '#22261F'},
  'landuse_park': {'fill-color': '#22261F'},
  'water_name': {'text-color': '#8FA6B2', 'text-halo-color': '#080B0D'},
  'building': {'fill-color': '#282521', 'fill-outline-color': '#33302B'},
  'aeroway-taxiway': {'line-color': '#3A3733'},
  'aeroway-runway-casing': {'line-color': 'rgba(110,105,98,0.8)'},
  'aeroway-area': {'fill-color': '#1F1D1B'},
  'aeroway-runway': {'line-color': '#4A4640'},
  'road_area_pier': {'fill-color': '#1B1A18'},
  'road_pier': {'line-color': '#1B1A18'},
  'highway_path': {'line-color': '#3A3733'},
  'highway_minor': {'line-color': '#3A3733'},
  'highway_major_casing': {'line-color': 'rgba(120,114,105,0.9)'},
  'highway_major_inner': {'line-color': '#4A4640'},
  'highway_major_subtle': {'line-color': '#3E3B36'},
  'highway_motorway_casing': {'line-color': 'rgba(140,133,122,0.9)'},
  'highway_motorway_inner': {
    'line-color': [
      'interpolate',
      ['linear'],
      ['zoom'],
      5.8,
      'hsla(0,0%,85%,0.53)',
      6,
      '#5E5850',
    ],
  },
  'highway_motorway_subtle': {'line-color': '#4A4640'},
  'railway_transit': {'line-color': '#4A4640'},
  'railway_transit_dashline': {'line-color': '#1B1A18'},
  'railway_minor': {'line-color': '#4A4640'},
  'railway_minor_dashline': {'line-color': '#1B1A18'},
  'railway': {'line-color': '#4A4640'},
  'railway_dashline': {'line-color': '#1B1A18'},
  'highway_name_other': {
    'text-color': '#A39E95',
    'text-halo-color': 'rgba(0,0,0,0.9)',
  },
  'highway_name_motorway': {'text-color': '#B8B2A8'},
  'boundary_state': {'line-color': '#5A554E'},
  'boundary_country_z0-4': {'line-color': '#7A756D'},
  'boundary_country_z5-': {'line-color': '#7A756D'},
  for (final id in const [
    'place_other',
    'place_suburb',
    'place_village',
    'place_town',
    'place_state',
    'place_country_other',
    'place_country_minor',
  ])
    id: {'text-color': '#D6D1C7', 'text-halo-color': 'rgba(0,0,0,0.85)'},
  for (final id in const [
    'place_city',
    'place_city_large',
    'place_country_major',
  ])
    id: {'text-color': '#ECE8E1', 'text-halo-color': 'rgba(0,0,0,0.85)'},
};

/// [style] (OpenFreeMap Dark) with [darkPaint] over its layers' paint; a
/// layer it does not name is left as it is.
Map<String, Object?> strongerDark(Map<String, Object?> style) => {
  ...style,
  'layers': [
    for (final layer in (style['layers'] as List).cast<Map<String, Object?>>())
      if (darkPaint[layer['id']] case final paint?)
        {
          ...layer,
          'paint': {...?(layer['paint'] as Map<String, Object?>?), ...paint},
        }
      else
        layer,
  ],
};
