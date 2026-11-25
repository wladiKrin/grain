import 'package:grain/map/openfreemap_dark.g.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/map/map_style_sheet.dart';
import 'package:grain/map/map_styles.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG relative luminance contrast of [a] and [b] (1 to 21).
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// A colour [c] drawn at its alpha over [under].
Color over(Color c, Color under) => Color.alphaBlend(c, under);

const _offline = OfflineSources(
  data: {
    'land': 'file:///data/cache/map/basemap-1/land.geojson',
    'lakes': 'file:///data/cache/map/basemap-1/lakes.geojson',
    'coast': 'file:///data/cache/map/basemap-1/coast.geojson',
    'borders': 'file:///data/cache/map/basemap-1/borders.geojson',
    'places': 'file:///data/cache/map/basemap-1/places.geojson',
  },
  placeZooms: [0, 1, 4, 8],
);

MapColors _colors(Brightness b) => MapColors.of(GrainPalette.of(b), b);

Map<String, Object?> _json(MapStyleDoc d) =>
    jsonDecode(d.style) as Map<String, Object?>;

List<Map<String, Object?>> _layers(Map<String, Object?> style) =>
    (style['layers']! as List).cast<Map<String, Object?>>();

Map<String, Object?> _layer(Map<String, Object?> style, String id) =>
    _layers(style).firstWhere((l) => l['id'] == id);

void main() {
  for (final b in Brightness.values) {
    group('$b colours', () {
      final g = GrainPalette.of(b);
      final c = MapColors.of(g, b);

      test('land and water are told apart', () {
        expect(contrast(c.land, c.water), greaterThanOrEqualTo(1.3));
      });

      test('shores and borders show on land, labels read', () {
        expect(contrast(c.coast, c.land), greaterThanOrEqualTo(1.6));
        expect(contrast(c.coast, c.water), greaterThanOrEqualTo(1.6));
        expect(
          contrast(over(c.border, c.land), c.land),
          greaterThanOrEqualTo(1.6),
        );
        expect(contrast(c.label, c.land), greaterThanOrEqualTo(4.5));
        expect(contrast(c.capital, c.land), greaterThanOrEqualTo(4.5));
      });

      test('neither is near black in dark mode', () {
        if (b == Brightness.dark) {
          // The near-black land of the first map (#151413) read as a blank
          // screen.
          expect(c.land.computeLuminance(), greaterThan(.02));
        } else {
          expect(c.land, g.ground);
        }
      });

      test('the offline style draws them, in that order', () {
        final s = offlineStyle(c, _offline);
        expect(s['version'], 8);
        expect(_layers(s).take(5).map((l) => l['id']), [
          'water',
          'land',
          'lakes',
          'coast',
          'borders',
        ]);
        expect(
          (_layer(s, 'water')['paint']! as Map)['background-color'],
          cssColor(c.water),
        );
        expect(
          (_layer(s, 'land')['paint']! as Map)['fill-color'],
          cssColor(c.land),
        );
        expect(
          (_layer(s, 'lakes')['paint']! as Map)['fill-color'],
          cssColor(c.water),
        );
        expect(_layer(s, 'coast')['paint'], {
          'line-color': cssColor(c.coast),
          'line-width': coastWidth,
        });
        expect(
          (_layer(s, 'borders')['paint']! as Map)['line-color'],
          cssColor(c.border),
        );
        final label = _layer(s, 'places-0');
        final paint = label['paint']! as Map;
        expect((paint['text-color']! as List).sublist(2), [
          cssColor(c.capital),
          cssColor(c.label),
        ]);
        expect(paint['text-halo-color'], cssColor(c.land));
      });
    });
  }

  test('colours are written as MapLibre reads them', () {
    expect(cssColor(const Color(0xFFC5D0D2)), 'rgba(197, 208, 210, 1.0)');
    expect(cssColor(const Color(0x80FF0000)), 'rgba(255, 0, 0, 0.502)');
  });

  group('offline', () {
    test('names only local files: the basemap in the cache, the glyphs in '
        'the APK', () {
      for (final b in Brightness.values) {
        final s = _json(mapStyleFor(MapStyle.offline, b, _colors(b), _offline));
        final urls = styleUrls(s).toList();
        expect(urls, hasLength(6));
        for (final u in urls) {
          expect(u, matches(RegExp(r'^(file|asset)://')), reason: u);
        }
        expect(s['glyphs'], glyphsUrl);
        expect(jsonEncode(s), isNot(contains('http')));
        expect(s.containsKey('sprite'), isFalse);
      }
    });

    test('with no basemap it is the water alone, and still offline', () {
      final doc = mapStyleFor(
        MapStyle.offline,
        Brightness.light,
        _colors(Brightness.light),
        null,
      );
      expect(doc.online, isFalse);
      final s = _json(doc);
      expect(styleUrls(s), isEmpty);
      expect(_layers(s).map((l) => l['id']), ['water']);
    });

    test('a label layer per zoom, the most prominent on top, from the '
        'zoom its places show', () {
      final s = offlineStyle(_colors(Brightness.light), _offline);
      final labels = [
        for (final l in _layers(s))
          if (l['type'] == 'symbol') l,
      ];
      expect(labels.map((l) => l['id']), [
        'places-8',
        'places-4',
        'places-1',
        'places-0',
      ]);
      for (final l in labels) {
        final z = int.parse((l['id']! as String).split('-').last);
        expect(l['minzoom'], z);
        expect(l['filter'], [
          '==',
          ['get', 'z'],
          z,
        ]);
        final layout = l['layout']! as Map;
        expect(jsonEncode(layout['text-font']), contains(regularFont));
        expect(jsonEncode(layout['text-font']), contains(boldFont));
      }
    });

    test('the basemap is cut into tiles to zoom 10, the places to the end', () {
      final s = offlineStyle(_colors(Brightness.dark), _offline);
      final sources = (s['sources']! as Map).cast<String, Map>();
      expect(sources.keys, _offline.data.keys);
      for (final MapEntry(:key, :value) in sources.entries) {
        expect(value['type'], 'geojson');
        expect(value['data'], _offline.data[key]);
        expect(value['maxzoom'], key == 'places' ? isNull : 10);
      }
    });
  });

  group('raster', () {
    test('each style names its server, zoom, paint and attribution', () {
      for (final b in Brightness.values) {
        for (final s in [
          MapStyle.offline,
          MapStyle.streets,
          MapStyle.minimal,
        ]) {
          expect(RasterTiles.of(s, b), isNull);
        }
        final standard = RasterTiles.of(MapStyle.standard, b)!;
        expect(standard.tiles, [
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ]);
        expect(standard.maxZoom, 19);
        expect(standard.paint, isEmpty);
        expect(standard.attribution, '© OpenStreetMap contributors');
        expect(standard.hosts, {'tile.openstreetmap.org'});

        final muted = RasterTiles.of(MapStyle.muted, b)!;
        expect(muted.tiles, standard.tiles);
        expect(muted.maxZoom, 19);
        expect(muted.attribution, standard.attribution);
        expect(
          muted.paint,
          b == Brightness.dark ? RasterTiles.mutedDark : RasterTiles.mutedLight,
        );

        final topo = RasterTiles.of(MapStyle.topographic, b)!;
        expect(topo.tiles, [
          for (final s in ['a', 'b', 'c'])
            'https://$s.tile.opentopomap.org/{z}/{x}/{y}.png',
        ]);
        expect(topo.maxZoom, 17);
        expect(topo.paint, isEmpty);
        expect(
          topo.attribution,
          '© OpenStreetMap contributors, SRTM · © OpenTopoMap (CC-BY-SA)',
        );
      }
    });

    test('Muted is grey: no colour, light tones squeezed in the light '
        'palette, inverted in the dark one', () {
      for (final p in [RasterTiles.mutedLight, RasterTiles.mutedDark]) {
        expect(p['raster-saturation'], -1.0);
        expect(p['raster-contrast'] as double, inInclusiveRange(-1, 0));
      }
      final light = RasterTiles.mutedLight, dark = RasterTiles.mutedDark;
      expect(light['raster-brightness-min'] as double, greaterThan(.3));
      expect(
        light['raster-brightness-max'] as double,
        greaterThan(light['raster-brightness-min'] as double),
      );
      // Dark: white land maps to near black, black text to light grey.
      expect(dark['raster-brightness-max'] as double, lessThan(.3));
      expect(
        dark['raster-brightness-min'] as double,
        greaterThan(dark['raster-brightness-max'] as double),
      );
    });

    test('tiles of 256 pixels over the offline land, with the paint', () {
      for (final b in Brightness.values) {
        final doc = mapStyleFor(MapStyle.muted, b, _colors(b), _offline);
        expect(doc.online, isTrue);
        expect(doc.hosts, {'tile.openstreetmap.org'});
        expect(doc.url, isNull);
        final s = _json(doc);
        final raster = (s['sources']! as Map)['raster'] as Map;
        expect(raster['type'], 'raster');
        expect(raster['tileSize'], 256);
        expect(raster['maxzoom'], 19);
        expect(raster['attribution'], osmAttribution);
        final layers = _layers(s);
        expect(layers.map((l) => l['id']), [
          'water',
          'land',
          'lakes',
          'coast',
          'borders',
          'raster',
        ]);
        expect(
          layers.last['paint'],
          b == Brightness.dark ? RasterTiles.mutedDark : RasterTiles.mutedLight,
        );
        // No labels under the tiles, so no glyphs to load.
        expect(s.containsKey('glyphs'), isFalse);
      }
      final standard = _json(
        mapStyleFor(
          MapStyle.standard,
          Brightness.dark,
          _colors(Brightness.dark),
          _offline,
        ),
      );
      expect(_layers(standard).last.containsKey('paint'), isFalse);
    });
  });

  test('Streets is OpenFreeMap Liberty; Minimal Positron, or Dark in the '
      'dark palette, as OpenFreeMap serves them', () {
    for (final b in Brightness.values) {
      final streets = mapStyleFor(MapStyle.streets, b, _colors(b), _offline);
      expect(streets.style, 'https://tiles.openfreemap.org/styles/liberty');
      expect(streets.url, streets.style);
      expect(streets.attribution, openFreeMapAttribution);
      expect(streets.hosts, {'tiles.openfreemap.org'});
    }
    expect(
      mapStyleFor(
        MapStyle.minimal,
        Brightness.light,
        _colors(Brightness.light),
        _offline,
      ).style,
      'https://tiles.openfreemap.org/styles/positron',
    );
    final dark = mapStyleFor(
      MapStyle.minimal,
      Brightness.dark,
      _colors(Brightness.dark),
      _offline,
    );
    // The bundled Dark with stronger contrast, still from OpenFreeMap.
    expect(dark.style, minimalDarkStyle);
    expect(dark.url, isNull);
    expect(dark.hosts, {'tiles.openfreemap.org'});
    expect(dark.attribution, openFreeMapAttribution);
  });

  group('Minimal in dark mode', () {
    final upstream = jsonDecode(openFreeMapDarkJson) as Map<String, Object?>;
    final lifted = jsonDecode(minimalDarkStyle) as Map<String, Object?>;
    List<Map<String, Object?>> layers(Map<String, Object?> s) =>
        (s['layers'] as List).cast<Map<String, Object?>>();
    Map<String, Object?> paintOf(String id) =>
        layers(lifted).firstWhere((l) => l['id'] == id)['paint']
            as Map<String, Object?>;

    test('keeps OpenFreeMap\'s sources, sprite, glyphs and layer order', () {
      expect(lifted['sources'], upstream['sources']);
      expect(lifted['sprite'], upstream['sprite']);
      expect(lifted['glyphs'], upstream['glyphs']);
      expect(
        layers(lifted).map((l) => l['id']),
        layers(upstream).map((l) => l['id']),
      );
      // Only paint changes: layout (fonts, sizes, fields) stays theirs.
      for (final (i, l) in layers(lifted).indexed) {
        expect(
          l['layout'],
          layers(upstream)[i]['layout'],
          reason: '${l['id']}',
        );
      }
    });

    test('every recoloured layer is in the style', () {
      final ids = layers(upstream).map((l) => l['id']).toSet();
      expect(darkPaint.keys.where((k) => !ids.contains(k)), isEmpty);
    });

    test('labels, roads and the sea stand out from the ground', () {
      Color c(Object v) =>
          Color(0xFF000000 | int.parse((v as String).substring(1), radix: 16));
      double contrast(Color a, Color b) {
        final (x, y) = (a.computeLuminance(), b.computeLuminance());
        return (math.max(x, y) + .05) / (math.min(x, y) + .05);
      }

      final ground = c(paintOf('background')['background-color']!);
      expect(
        contrast(c(paintOf('place_city')['text-color']!), ground),
        greaterThan(12),
      );
      expect(
        contrast(c(paintOf('place_town')['text-color']!), ground),
        greaterThan(10),
      );
      expect(
        contrast(c(paintOf('highway_name_other')['text-color']!), ground),
        greaterThan(6),
      );
      expect(
        contrast(c(paintOf('highway_major_inner')['line-color']!), ground),
        greaterThan(1.8),
      );
      expect(
        contrast(c(paintOf('water')['fill-color']!), ground),
        greaterThan(1.05),
      );
      // OpenFreeMap's own place labels were about 3:1.
      final before = layers(upstream)
          .firstWhere((l) => l['id'] == 'place_city');
      expect((before['paint'] as Map)['text-color'], 'rgb(101,101,101)');
    });
  });

  test('every style but Offline is online; each is its own per palette', () {
    for (final s in MapStyle.values) {
      final docs = [
        for (final b in Brightness.values)
          mapStyleFor(s, b, _colors(b), _offline),
      ];
      for (final d in docs) {
        expect(d.online, s.online, reason: s.name);
      }
      // Only Streets is the same in both: the others draw the palette's
      // land and water under them, or are Positron or Dark.
      expect(docs.first == docs.last, s == MapStyle.streets, reason: s.name);
    }
  });

  test('the old Minimal tile server is gone: no style, server, credit or '
      'doc names it', () {
    // Spelled apart, so that a grep of the repository finds it nowhere.
    final gone = ['car', 'to'].join();
    final strings = [
      ...mapStyleLabels.values,
      ...mapStyleSubtitles.values,
      for (final s in MapStyle.values)
        for (final b in Brightness.values) ...[
          mapStyleFor(s, b, _colors(b), _offline).style,
          mapStyleFor(s, b, _colors(b), _offline).attribution,
        ],
    ];
    for (final s in strings) {
      expect(s.toLowerCase(), isNot(contains(gone)));
    }
    for (final dir in ['lib', 'docs', 'fastlane', 'android/app/src/main']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File) continue;
        expect(
          utf8.decode(f.readAsBytesSync(), allowMalformed: true).toLowerCase(),
          isNot(contains(gone)),
          reason: f.path,
        );
      }
    }
    expect(
      File('README.md').readAsStringSync().toLowerCase(),
      isNot(contains(gone)),
    );
  });

  test('the User-Agent names Grain and its repository', () {
    expect(osmUserAgent, startsWith('Grain/'));
    expect(osmUserAgent, contains('https://github.com/wladiKrin/grain'));
  });
}
