import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:grain/gear/codec.dart';
import 'package:grain/gear/model.dart';

/// The bundled community library of bodies and lenses.
class GearLibrary {
  GearLibrary({
    required List<Body> bodies,
    required List<Lens> lenses,
    List<String> errors = const [],
  }) : bodies = List.unmodifiable(bodies),
       lenses = List.unmodifiable(lenses),
       errors = List.unmodifiable(errors);

  const GearLibrary.empty()
    : bodies = const [],
      lenses = const [],
      errors = const [];

  final List<Body> bodies;
  final List<Lens> lenses;

  /// One entry per skipped file: its path, then the problems found.
  final List<String> errors;

  static Future<GearLibrary> load(AssetBundle bundle) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final paths = manifest.listAssets().where((p) {
      if (!p.endsWith('.json')) return false;
      return p.startsWith('library/bodies/') || p.startsWith('library/lenses/');
    }).toList()..sort();
    final bodies = <Body>[];
    final lenses = <Lens>[];
    final errors = <String>[];
    for (final path in paths) {
      try {
        final doc = parseGearString(await bundle.loadString(path));
        if (doc is Body && path.startsWith('library/bodies/')) {
          bodies.add(doc);
        } else if (doc is Lens && path.startsWith('library/lenses/')) {
          lenses.add(doc);
        } else {
          errors.add('$path: wrong kind of file for its directory');
        }
      } on GearFormatException catch (e) {
        errors.add('$path: ${e.errors.join('; ')}');
      } catch (e) {
        errors.add('$path: $e');
      }
    }
    for (final e in errors) {
      debugPrint('Grain library: $e');
    }
    return GearLibrary(bodies: bodies, lenses: lenses, errors: errors);
  }

  Body? body(String id) {
    for (final b in bodies) {
      if (b.id == id) return b;
    }
    return null;
  }

  Lens? lens(String id) {
    for (final l in lenses) {
      if (l.id == id) return l;
    }
    return null;
  }
}
