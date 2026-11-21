import 'dart:io';

import 'package:grain/gear/codec.dart';
import 'package:grain/gear/library.dart';
import 'package:grain/gear/model.dart';

/// Reads and parses `library/**/<id>.json` from the repository.
GearDoc _libDoc(String id) {
  for (final e in Directory('library').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('${Platform.pathSeparator}$id.json')) {
      return parseGearString(e.readAsStringSync());
    }
  }
  throw StateError('no library file for $id');
}

Body libBody(String id) => _libDoc(id) as Body;
Lens libLens(String id) => _libDoc(id) as Lens;

/// Every bundled library file, parsed.
GearLibrary fixtureLibrary() {
  final bodies = <Body>[];
  final lenses = <Lens>[];
  final files =
      Directory('library')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json') && !f.path.contains('schema'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final doc = parseGearString(f.readAsStringSync());
    if (doc is Body) bodies.add(doc);
    if (doc is Lens) lenses.add(doc);
  }
  return GearLibrary(bodies: bodies, lenses: lenses);
}
