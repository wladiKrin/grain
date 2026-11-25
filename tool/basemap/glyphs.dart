// Builds assets/map/glyphs/, the glyphs the offline map's place names are
// drawn with, from the openmaptiles/fonts Noto Sans PBFs (SIL Open Font
// License 1.1). Reproduce with:
//
//   curl -sSfL -o build/noto-sans.zip \
//     https://github.com/openmaptiles/fonts/releases/download/v2.0/noto-sans.zip
//   unzip -q build/noto-sans.zip -d build/noto-sans
//   dart run tool/basemap/glyphs.dart build/noto-sans assets/map/basemap.bin \
//     assets/map/glyphs
//
// Each range MapLibre may ask for (glyphs.dart's glyphRanges) is kept for
// Noto Sans Regular and Bold, with printable ASCII and the characters the
// place names use only. A glyph PBF is
//   glyphs { repeated fontstack stacks = 1; }
//   fontstack { string name = 1; string range = 2; repeated glyph glyphs = 3; }
//   glyph { uint32 id = 1; ... }
// and the glyphs are copied as they are.
import 'dart:io';
import 'dart:typed_data';

import 'package:grain/map/basemap.dart';
import 'package:grain/map/glyphs.dart';

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'usage: glyphs.dart <noto-sans dir> <basemap.bin> <out dir>',
    );
    exit(64);
  }
  final map = Basemap.decode(File(args[1]).readAsBytesSync());
  final used = <int>{0x20, 0x2022};
  for (final p in map.places) {
    used.addAll(p.name.runes);
  }
  final fonts = {regularFont: 'Noto Sans Regular', boldFont: 'Noto Sans Bold'};
  var total = 0;
  for (final MapEntry(key: folder, value: font) in fonts.entries) {
    for (final start in glyphRanges) {
      final range = '$start-${start + 255}';
      final src = File('${args[0]}/$font/$range.pbf').readAsBytesSync();
      final out = subset(
        src,
        (id) => (id >= 0x20 && id < 0x7F) || used.contains(id),
      );
      File('${args[2]}/$folder/$range.pbf')
        ..createSync(recursive: true)
        ..writeAsBytesSync(out);
      total += out.length;
    }
  }
  final missing = used.where((c) => !glyphRanges.contains(c & ~0xFF)).toList();
  if (missing.isNotEmpty) {
    stderr.writeln(
      'Place names use characters past the ranges kept: '
      '${String.fromCharCodes(missing)}',
    );
    exit(1);
  }
  stdout.writeln('${args[2]}: $total bytes');
}

/// [pbf] with only the glyphs whose id [keep] takes.
Uint8List subset(Uint8List pbf, bool Function(int id) keep) {
  final out = BytesBuilder();
  for (final (field, stack) in _fields(pbf)) {
    if (field != 1 || stack is! Uint8List) continue;
    final s = BytesBuilder();
    for (final (f, v) in _fields(stack)) {
      if (v is! Uint8List) continue;
      if (f == 3) {
        final id = _fields(v).firstWhere((e) => e.$1 == 1).$2 as int;
        if (!keep(id)) continue;
      }
      _bytesField(s, f, v);
    }
    _bytesField(out, 1, s.takeBytes());
  }
  return out.takeBytes();
}

/// The fields of a protobuf message: varints as ints, length-delimited ones
/// as bytes (the only kinds in a glyph PBF's messages that matter here).
List<(int, Object)> _fields(Uint8List b) {
  final out = <(int, Object)>[];
  var i = 0;
  int varint() {
    var v = 0, shift = 0;
    while (true) {
      final c = b[i++];
      v |= (c & 0x7F) << shift;
      if (c < 0x80) return v;
      shift += 7;
    }
  }

  while (i < b.length) {
    final key = varint();
    switch (key & 7) {
      case 0:
        out.add((key >> 3, varint()));
      case 2:
        final n = varint();
        out.add((key >> 3, Uint8List.sublistView(b, i, i + n)));
        i += n;
      case 5:
        i += 4;
      case 1:
        i += 8;
      default:
        throw FormatException('wire type ${key & 7}');
    }
  }
  return out;
}

void _varint(BytesBuilder b, int v) {
  while (v >= 0x80) {
    b.addByte((v & 0x7F) | 0x80);
    v >>= 7;
  }
  b.addByte(v);
}

void _bytesField(BytesBuilder b, int field, Uint8List v) {
  _varint(b, field << 3 | 2);
  _varint(b, v.length);
  b.add(v);
}
