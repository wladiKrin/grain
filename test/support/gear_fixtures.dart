import 'dart:io';

import 'package:grain/gear/codec.dart';
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
