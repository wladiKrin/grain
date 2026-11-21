import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/codec.dart';
import 'package:grain/gear/model.dart';
import 'package:json_schema/json_schema.dart';

List<File> _files(String sub) =>
    Directory('library/$sub')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

String _rel(File f) => f.path.replaceAll('\\', '/');
String _base(File f) => _rel(f).split('/').last;
String _dir(File f) {
  final parts = _rel(f).split('/');
  return parts[parts.length - 2];
}

Map<File, GearDoc> _parsed(String sub) => {
  for (final f in _files(sub)) f: parseGearString(f.readAsStringSync()),
};

void main() {
  final schema = JsonSchema.create(
    jsonDecode(File('library/schema/gear-1.schema.json').readAsStringSync()),
  );

  test('there are library files to check', () {
    expect(_files('bodies'), isNotEmpty);
    expect(_files('lenses'), isNotEmpty);
  });

  test('every library file is valid against the schema and the parser', () {
    for (final f in [..._files('bodies'), ..._files('lenses')]) {
      final text = f.readAsStringSync();
      final result = schema.validate(jsonDecode(text));
      if (!result.isValid) {
        // ignore: avoid_print
        print(
          '${f.path}: ${result.errors.map((e) => e.toString()).join('; ')}',
        );
      }
      expect(result.isValid, isTrue, reason: f.path);
      expect(() => parseGearString(text), returnsNormally, reason: f.path);
      expect(
        encodePretty(parseGearString(text)),
        text,
        reason: '${f.path} is not in canonical encodePretty form',
      );
    }
  });

  test('type, file name and directory follow the layout', () {
    for (final e in _parsed('bodies').entries) {
      final b = e.value;
      expect(b, isA<Body>(), reason: e.key.path);
      b as Body;
      expect(_base(e.key), '${b.id}.json');
      expect(_dir(e.key), b.make.toLowerCase().replaceAll(' ', '-'));
    }
    for (final e in _parsed('lenses').entries) {
      final l = e.value;
      expect(l, isA<Lens>(), reason: e.key.path);
      l as Lens;
      expect(_base(e.key), '${l.id}.json');
      expect(_dir(e.key), l.mount);
    }
  });

  test('ids are unique per kind', () {
    for (final sub in ['bodies', 'lenses']) {
      final ids = _parsed(sub).values
          .map((d) => (d as GearProfile).id)
          .toList();
      expect(ids.toSet().length, ids.length, reason: sub);
    }
  });

  test('every library directory is declared as an asset in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final flutterPart = pubspec.substring(pubspec.indexOf('\nflutter:'));
    final declared = RegExp(
      r'^\s*- (library/[^\s#]+)\s*$',
      multiLine: true,
    ).allMatches(flutterPart).map((m) => m[1]!).toSet();
    final dirs = {
      for (final f in [..._files('bodies'), ..._files('lenses')])
        '${f.parent.path.replaceAll('\\', '/')}/',
    };
    for (final d in dirs) {
      expect(declared, contains(d), reason: 'pubspec.yaml lacks "- $d"');
    }
    for (final d in declared) {
      expect(dirs, contains(d), reason: 'asset $d has no json files');
    }
  });

  test('Canon A-1 and FD 50mm f/1.8 are bundled with the spec values', () {
    final a1 = _parsed('bodies').values
        .whereType<Body>()
        .firstWhere((b) => b.id == 'canon-a1');
    expect(a1.mount, 'canon-fd');
    expect(a1.format, FilmFormat.f135);
    expect(a1.shutter, [
      '1/1000', '1/500', '1/250', '1/125', '1/60', '1/30', '1/15', '1/8',
      '1/4', '1/2', '1', '2', '4', '8', '15', '30', 'B', //
    ]);
    expect(a1.isoMin, 6);
    expect(a1.isoMax, 12800);
    final fd = _parsed('lenses').values
        .whereType<Lens>()
        .firstWhere((l) => l.id == 'canon-fd-50-1.8');
    expect(fd.focalMin, 50);
    expect(fd.focalMax, 50);
    expect(fd.maxAperture, [const ApertureAt(50, 1.8)]);
    expect(fd.minAperture, 22);
    expect(fd.apertureStep.name, 'half');
  });

  test('every lens mount has a body', () {
    final bodyMounts = _parsed('bodies').values
        .whereType<Body>()
        .map((b) => b.mount)
        .toSet();
    for (final l in _parsed('lenses').values.whereType<Lens>()) {
      expect(bodyMounts, contains(l.mount), reason: l.id);
    }
  });
}
