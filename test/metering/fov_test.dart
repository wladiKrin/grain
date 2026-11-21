import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/metering/fov.dart';

void main() {
  test('50 mm on a 25 mm-equivalent phone crops to half the diagonal', () {
    final r = lensCrop(
      preview: const Size(3, 4),
      lensFocal: 50,
      phoneEqFocal: 25,
    );
    expect(r.center.dx, closeTo(.5, 1e-9));
    expect(r.center.dy, closeTo(.5, 1e-9));
    expect(r.width, closeTo(.4623, 1e-3));
    expect(r.height, closeTo(.5200, 1e-3));
  });

  test('lens wider than phone gives the full fitting 2:3 rect', () {
    final r = lensCrop(
      preview: const Size(3, 4),
      lensFocal: 12,
      phoneEqFocal: 25,
    );
    expect(widerThanPhone(12, 25), isTrue);
    expect(widerThanPhone(50, 25), isFalse);
    // 3x4 preview: 2:3 rect limited by width -> 3 x 4.5 does not fit, so 8/3 x 4.
    expect(r.height, closeTo(1, 1e-9));
    expect(r.width * 3 / (r.height * 4), closeTo(2 / 3, 1e-9));
    expect(r.center.dx, closeTo(.5, 1e-9));
  });

  test('focalStops spans 12..600', () {
    expect(focalStops.first, 12);
    expect(focalStops.last, 600);
    expect(focalStops, contains(50));
  });
}
