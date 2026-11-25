import 'dart:convert';
import 'dart:typed_data';

import 'geo.dart';

/// The offline basemap: Natural Earth land, lakes, country borders and
/// populated places, as drawn under the logged locations.
///
/// Pure Dart (no Flutter), so `tool/basemap/encode.dart` can write it.
///
/// File format (`GMAP`, version 1), all integers unsigned LEB128 varints
/// unless noted; coordinates are degrees × [Basemap.scale] as zigzag
/// varints, each point a delta (latitude, then longitude) from the previous
/// point of its ring or line, the first from 0:
///
/// ```
/// 'G' 'M' 'A' 'P'  u8 version
/// polygons land    count, then per polygon: rings, then per ring: n, points
/// polygons lakes   (as land; the first ring is the outline, then holes)
/// lines borders    count, then per line: n, points
/// places           count, then per place: lat, lon (zigzag, absolute),
///                  u8 min zoom × 10, u8 flags, name length, UTF-8 name
/// ```
class Basemap {
  const Basemap({
    this.land = const [],
    this.lakes = const [],
    this.borders = const [],
    this.places = const [],
  });

  /// Fixed-point resolution: 1e-4 degree, about 11 m.
  static const scale = 10000;
  static const version = 1;
  static const _magic = [0x47, 0x4D, 0x41, 0x50]; // GMAP

  final List<MapPolygon> land;
  final List<MapPolygon> lakes;
  final List<List<GeoPoint>> borders;

  /// Most prominent first: drawn in this order, a label that would overlap
  /// one already drawn is left out.
  final List<Place> places;

  /// Reads the bytes [encode] writes; throws [FormatException] on anything
  /// else.
  static Basemap decode(Uint8List bytes) => _Reader(bytes).basemap();

  Uint8List encode() {
    final w = _Writer();
    for (final b in _magic) {
      w.byte(b);
    }
    w.byte(version);
    w.polygons(land);
    w.polygons(lakes);
    w.uint(borders.length);
    for (final l in borders) {
      w.ring(l);
    }
    w.uint(places.length);
    for (final p in places) {
      w.sint(_fixed(p.position.latitude));
      w.sint(_fixed(p.position.longitude));
      w.byte((p.minZoom * 10).round().clamp(0, 255));
      w.byte(p.capital ? 1 : 0);
      final name = utf8.encode(p.name);
      w.uint(name.length);
      w.bytes(name);
    }
    return w.done();
  }
}

int _fixed(double deg) => (deg * Basemap.scale).round();

/// An area: its outline and any holes.
class MapPolygon {
  const MapPolygon(this.outline, [this.holes = const []]);

  final List<GeoPoint> outline;
  final List<List<GeoPoint>> holes;
}

/// A named place, labelled from [minZoom] on.
class Place {
  const Place({
    required this.name,
    required this.position,
    required this.minZoom,
    this.capital = false,
  });

  final String name;
  final GeoPoint position;
  final double minZoom;

  /// A country's capital.
  final bool capital;
}

class _Writer {
  final _b = BytesBuilder(copy: false);

  void byte(int v) => _b.addByte(v);

  void bytes(List<int> v) => _b.add(v);

  void uint(int v) {
    assert(v >= 0);
    while (v >= 0x80) {
      _b.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    _b.addByte(v);
  }

  void sint(int v) => uint(v >= 0 ? v << 1 : ((-v) << 1) - 1);

  void ring(List<GeoPoint> points) {
    uint(points.length);
    var lat = 0, lon = 0;
    for (final p in points) {
      final y = _fixed(p.latitude), x = _fixed(p.longitude);
      sint(y - lat);
      sint(x - lon);
      lat = y;
      lon = x;
    }
  }

  void polygons(List<MapPolygon> list) {
    uint(list.length);
    for (final p in list) {
      uint(1 + p.holes.length);
      ring(p.outline);
      for (final h in p.holes) {
        ring(h);
      }
    }
  }

  Uint8List done() => _b.takeBytes();
}

class _Reader {
  _Reader(this._b);

  final Uint8List _b;
  int _i = 0;

  int byte() {
    if (_i >= _b.length) throw const FormatException('Basemap: truncated');
    return _b[_i++];
  }

  int uint() {
    var v = 0, shift = 0;
    while (true) {
      final b = byte();
      v |= (b & 0x7F) << shift;
      if (b < 0x80) return v;
      shift += 7;
      if (shift > 49) throw const FormatException('Basemap: bad varint');
    }
  }

  int sint() {
    final v = uint();
    return (v & 1) == 0 ? v >> 1 : -((v + 1) >> 1);
  }

  List<GeoPoint> ring() {
    final n = uint();
    var lat = 0, lon = 0;
    return List.generate(n, (_) {
      lat += sint();
      lon += sint();
      return GeoPoint(lat / Basemap.scale, lon / Basemap.scale);
    }, growable: false);
  }

  List<MapPolygon> polygons() => List.generate(uint(), (_) {
    final rings = uint();
    if (rings == 0) throw const FormatException('Basemap: empty polygon');
    final outline = ring();
    return MapPolygon(outline, [for (var r = 1; r < rings; r++) ring()]);
  }, growable: false);

  Basemap basemap() {
    for (final m in Basemap._magic) {
      if (byte() != m) throw const FormatException('Basemap: not a GMAP file');
    }
    final v = byte();
    if (v != Basemap.version) {
      throw FormatException('Basemap: version $v not supported');
    }
    final land = polygons();
    final lakes = polygons();
    final borders = List.generate(uint(), (_) => ring(), growable: false);
    final places = List.generate(uint(), (_) {
      final lat = sint() / Basemap.scale;
      final lon = sint() / Basemap.scale;
      final minZoom = byte() / 10;
      final flags = byte();
      final len = uint();
      if (_i + len > _b.length) {
        throw const FormatException('Basemap: truncated');
      }
      final name = utf8.decode(Uint8List.sublistView(_b, _i, _i + len));
      _i += len;
      return Place(
        name: name,
        position: GeoPoint(lat, lon),
        minZoom: minZoom,
        capital: flags & 1 != 0,
      );
    }, growable: false);
    if (_i != _b.length) throw const FormatException('Basemap: trailing bytes');
    return Basemap(land: land, lakes: lakes, borders: borders, places: places);
  }
}
