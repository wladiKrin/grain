import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/library.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final k in files.keys)
          k: [
            {'asset': k},
          ],
      })!;
    }
    final text = files[key];
    if (text == null) throw StateError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

const _lens =
    '{"schema":1,"type":"lens","id":"x-50","make":"X","name":"X 50mm f/2","mount":"x","focal":50,"maxAperture":2,"minAperture":16,"apertureStep":"half"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled library from assets', () async {
    final lib = await GearLibrary.load(rootBundle);
    expect(lib.errors, isEmpty);
    expect(lib.body('canon-a1')!.model, 'A-1');
    expect(lib.bodies.length, 11);
    expect(lib.lenses.length, 18);
    expect(lib.lens('canon-fd-50-1.8')!.maxAperture.first.aperture, 1.8);
    expect(lib.body('nope'), isNull);
    expect(lib.lens('nope'), isNull);
  });

  test('an invalid asset is skipped and reported', () async {
    final lib = await GearLibrary.load(
      _FakeBundle({
        'library/lenses/x/x-50.json': _lens,
        'library/lenses/x/bad.json': '{}',
        'library/schema/gear-1.schema.json': '{}',
      }),
    );
    expect(lib.lenses.length, 1);
    expect(lib.lenses.single.id, 'x-50');
    expect(lib.errors.length, 1);
    expect(lib.errors.single, contains('library/lenses/x/bad.json'));
  });

  test('empty library has nothing', () {
    const lib = GearLibrary.empty();
    expect(lib.bodies, isEmpty);
    expect(lib.lenses, isEmpty);
    expect(lib.errors, isEmpty);
  });
}
