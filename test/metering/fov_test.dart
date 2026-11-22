import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/model.dart';
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

  test('6×6 80 mm on a 25 mm-equivalent phone', () {
    expect(equivalentFocal(80, FilmFormat.f66), closeTo(43.71, .01));
    final r = lensCrop(
      preview: const Size(3, 4),
      lensFocal: equivalentFocal(80, FilmFormat.f66),
      phoneEqFocal: 25,
      aspect: FilmFormat.f66.portraitAspect,
    );
    expect(r.width, closeTo(.6740, 1e-3));
    expect(r.height, closeTo(.5055, 1e-3));
  });

  group('lensFits on a 3:4 preview of a 25 mm-equivalent camera', () {
    bool fits(double focal, double aspect) => lensFits(
      preview: const Size(3, 4),
      lensFocal: focal,
      phoneEqFocal: 25,
      aspect: aspect,
    );

    test('upright 2:3 fits down to about 26 mm', () {
      expect(fits(50, 2 / 3), isTrue);
      expect(fits(26.1, 2 / 3), isTrue);
      expect(fits(25.9, 2 / 3), isFalse);
      expect(fits(12, 2 / 3), isFalse);
    });

    test('sideways 3:2 is limited by the width: fits down to about 35 mm', () {
      expect(fits(35, 3 / 2), isTrue);
      expect(fits(34, 3 / 2), isFalse);
    });

    test('a sideways crop is wide and centred', () {
      final r = lensCrop(
        preview: const Size(3, 4),
        lensFocal: 50,
        phoneEqFocal: 25,
        aspect: FilmFormat.f135.aspect(landscape: true),
      );
      expect(r.width * 3 / (r.height * 4), closeTo(3 / 2, 1e-9));
      expect(r.center, const Offset(.5, .5));
    });
  });
}
